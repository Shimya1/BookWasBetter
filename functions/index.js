const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

const booksApiKey = defineSecret('BOOKS_API_KEY');

// ─── Auth helper ──────────────────────────────────────────────────────────────

async function verifyAuth(req, res) {
  const authHeader = req.headers.authorization ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  try {
    return await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);
  } catch {
    res.status(401).json({ error: 'Invalid token' });
    return null;
  }
}

// ─── searchBooks ──────────────────────────────────────────────────────────────

exports.searchBooks = onRequest(
  { secrets: [booksApiKey], cors: true },
  async (req, res) => {
    if (!await verifyAuth(req, res)) return;

    const query = req.body?.query;
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return res.status(400).json({ error: 'A search query is required.' });
    }

    try {
      const response = await axios.get(
        'https://www.googleapis.com/books/v1/volumes',
        {
          params: {
            q: query.trim(),
            maxResults: 20,
            printType: 'books',
            key: booksApiKey.value(),
          },
        }
      );

      const items = response.data.items ?? [];

      const results = items
        .map((item) => {
          const info = item.volumeInfo ?? {};
          const authors = info.authors ?? [];
          const imageLinks = info.imageLinks ?? {};
          const hasCover = !!(imageLinks.thumbnail || imageLinks.smallThumbnail);

          return {
            googleBooksId: item.id,
            title: info.title ?? 'Unknown Title',
            author: authors.length > 0 ? authors.join(', ') : 'Unknown Author',
            // Return a placeholder flag — cover will be fetched when book is added
            hasCover,
            coverUrl: hasCover
              ? `https://books.google.com/books/publisher/content/images/frontcover/${item.id}?fife=w300-h450&source=gbs_api`
              : '',
            description: info.description ?? 'No description available.',
          };
        })
        .filter((result) => result.hasCover);

      return res.status(200).json({ results });
    } catch (error) {
      console.error('Google Books API error:', error.message);
      console.error('Response data:', JSON.stringify(error.response?.data));
      return res.status(500).json({ error: 'Failed to fetch results from Google Books.' });
    }
  }
);

// ─── fetchAndStoreCover ───────────────────────────────────────────────────────
// Downloads a book cover from Google Books and stores it in Firebase Storage.
// Returns the public Firebase Storage URL (CORS-enabled, CDN-backed).

exports.fetchAndStoreCover = onRequest(
  { cors: true },
  async (req, res) => {
    if (!await verifyAuth(req, res)) return;

    const { googleBooksId } = req.body ?? {};
    if (!googleBooksId) {
      return res.status(400).json({ error: 'Missing googleBooksId' });
    }

    const bucket = admin.storage().bucket('thebookwasbetter-d4381.firebasestorage.app');
    const filePath = `covers/${googleBooksId}.jpg`;
    const file = bucket.file(filePath);

    // Return cached version if already stored
    const [exists] = await file.exists();
    if (exists) {
      const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media`;
      return res.json({ coverUrl: publicUrl });
    }

    // Fetch from Google Books and upload to Firebase Storage
    try {
      const imageUrl = `https://books.google.com/books/publisher/content/images/frontcover/${googleBooksId}?fife=w300-h450&source=gbs_api`;
      const imageResponse = await axios.get(imageUrl, { responseType: 'arraybuffer' });

      await file.save(Buffer.from(imageResponse.data), {
        contentType: 'image/jpeg',
        public: true,
      });

      const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media`;
      return res.json({ coverUrl: publicUrl });
    } catch (error) {
      console.error('Cover fetch error:', error.message);
      return res.status(500).json({ error: 'Failed to fetch cover image.' });
    }
  }
);
