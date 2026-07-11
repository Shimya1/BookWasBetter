const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
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
            hasCover,
            coverUrl: hasCover
              ? `https://books.google.com/books/publisher/content/images/frontcover/${item.id}?fife=w300-h450&source=gbs_api`
              : '',
            description: info.description ?? 'No description available.',
            categories: info.categories ?? [],
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


// ─── Election tallying ────────────────────────────────────────────────────────
// Shared by both triggers below. Re-checks closedAt/tiedBookIds at the top so
// it's safe to call from either trigger without double-tallying in the
// common case — though a true simultaneous race (last vote landing in the
// same instant the deadline ticks over) isn't fully transaction-locked here.
// Low-stakes enough for a book club app that this is an acceptable tradeoff.

async function tallyElection(clubId, electionId) {
  const db = admin.firestore();
  const electionRef = db
    .collection('clubs')
    .doc(clubId)
    .collection('elections')
    .doc(electionId);

  const electionSnap = await electionRef.get();
  if (!electionSnap.exists) return;
  const election = electionSnap.data();

  // Already settled or already waiting on the owner to break a tie.
  if (election.closedAt != null || election.tiedBookIds != null) return;

  const [nominationsSnap, votesSnap] = await Promise.all([
    electionRef.collection('nominations').get(),
    electionRef.collection('votes').get(),
  ]);

  const eligibleCount = (election.eligibleVoterUids ?? []).length;
  const deadlinePassed = Date.now() >= new Date(election.votingEndTime).getTime();
  const everyoneVoted = eligibleCount > 0 && votesSnap.size >= eligibleCount;

  if (!deadlinePassed && !everyoneVoted) return; // not time yet

  const nominationsById = {};
  nominationsSnap.forEach((doc) => {
    const n = doc.data();
    nominationsById[n.googleBooksId] = n;
  });

  const counts = {};
  votesSnap.forEach((doc) => {
    const id = doc.data().googleBooksId;
    counts[id] = (counts[id] ?? 0) + 1;
  });

  let winners = [];
  let maxVotes = 0;
  for (const [id, count] of Object.entries(counts)) {
    if (count > maxVotes) {
      maxVotes = count;
      winners = [id];
    } else if (count === maxVotes) {
      winners.push(id);
    }
  }

  const clubRef = db.collection('clubs').doc(clubId);

  if (winners.length === 0) {
    // Nobody voted — close it out so the club isn't stuck with a dead election.
    await electionRef.update({ closedAt: new Date().toISOString() });
    await clubRef.update({ activeElectionId: null });
    return;
  }

  if (winners.length > 1) {
    // Order tied books by earliest nomination, purely for display —
    // the owner still makes the actual call via resolveTie.
    winners.sort((a, b) => {
      const ta = nominationsById[a]?.submittedAt ?? '';
      const tb = nominationsById[b]?.submittedAt ?? '';
      return ta.localeCompare(tb);
    });
    await electionRef.update({ tiedBookIds: winners });
    return;
  }

  const winningBookId = winners[0];
  const winningNomination = nominationsById[winningBookId];
  const title = winningNomination?.title ?? 'the selected book';
  const author = winningNomination?.author ?? '';
  const coverUrl = winningNomination?.coverUrl ?? '';

  const batch = db.batch();
  batch.update(electionRef, {
    winningBookId,
    closedAt: new Date().toISOString(),
  });
  batch.update(clubRef, {
    activeBookId: winningBookId,
    activeElectionId: null,
  });

  const libraryRef = clubRef.collection('libraryBooks');
  const openEntrySnap = await libraryRef
    .where('finishedAt', '==', null)
    .limit(1)
    .get();
  if (!openEntrySnap.empty) {
    batch.update(openEntrySnap.docs[0].ref, {
      finishedAt: new Date().toISOString(),
    });
  }
  batch.set(libraryRef.doc(), {
    googleBooksId: winningBookId,
    title,
    author,
    coverUrl,
    selectedAt: new Date().toISOString(),
    finishedAt: null,
    selectionMethod: 'election',
    selectedByUid: null,
    selectedByName: null,
  });

  await batch.commit();

  await clubRef.collection('activity').add({
    type: 'bookSelected',
    actorUid: 'system',
    actorName: 'The vote',
    targetName: title,
    createdAt: new Date().toISOString(),
  });
}

// Early close — re-tally every time a vote is cast or changed, in case that
// was the last eligible voter.
exports.onVoteWritten = onDocumentWritten(
  'clubs/{clubId}/elections/{electionId}/votes/{voterId}',
  async (event) => {
    const { clubId, electionId } = event.params;
    await tallyElection(clubId, electionId);
  }
);

// Backstop — catches elections where the deadline passed without everyone
// voting.
exports.checkElectionDeadlines = onSchedule('every 15 minutes', async () => {
  const db = admin.firestore();
  const nowIso = new Date().toISOString();

  const snap = await db
    .collectionGroup('elections')
    .where('closedAt', '==', null)
    .where('votingEndTime', '<=', nowIso)
    .get();

  await Promise.all(
    snap.docs.map((doc) => {
      const clubId = doc.ref.parent.parent.id;
      return tallyElection(clubId, doc.id);
    })
  );
});

// Club library notes — bypasses the fragile collectionGroup rule by
// checking club membership server-side instead of via per-note get() calls.
exports.getClubBookNotes = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const { clubId, googleBooksId } = request.data || {};
  if (!clubId || !googleBooksId) {
    throw new HttpsError('invalid-argument', 'clubId and googleBooksId are required.');
  }

  const db = admin.firestore();

  const clubSnap = await db.collection('clubs').doc(clubId).get();
  const memberUids = clubSnap.data()?.memberUids ?? [];
  if (!memberUids.includes(uid)) {
    throw new HttpsError('permission-denied', 'Not a member of this club.');
  }

  const notesSnap = await db
    .collectionGroup('notes')
    .where('googleBooksId', '==', googleBooksId)
    .where('public', '==', true)
    .get();

  const notes = notesSnap.docs
    .filter((doc) => {
      const data = doc.data();
      const clubs = data.clubs ?? [];
      // Tagged to specific clubs — must include this one.
      if (clubs.length > 0) return clubs.includes(clubId);
      // "All my clubs" sentinel — only show if the author is also a
      // member of this specific club.
      return memberUids.includes(data.userId);
    })
    .map((doc) => ({ id: doc.id, ...doc.data() }));

  return { notes };
});