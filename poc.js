const cache = new Map();
const TTL_MS = 5000;

function cacheGet(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    cache.delete(key);
    return null;
  }
  return entry.value;
}

function cacheSet(key, value) {
  cache.set(key, { value, expiresAt: Date.now() + TTL_MS });
}

function fetchFromDB(userId) {
  return new Promise((resolve) => {
    const latency = 100 + Math.floor(Math.random() * 100);
    setTimeout(() => resolve({ id: userId, name: `User_${userId}` }), latency);
  });
}

async function getUser(userId) {
  const key = `user:${userId}`;
  const start = performance.now();
  const cached = cacheGet(key);
  if (cached) {
    console.log(
      `CACHE HIT   id=${userId}  ${(performance.now() - start).toFixed(3)}ms`,
    );
    return cached;
  }
  const user = await fetchFromDB(userId);
  cacheSet(key, user);
  console.log(
    `CACHE MISS  id=${userId}  ${(performance.now() - start).toFixed(3)}ms`,
  );
  return user;
}

// Run
for (const id of [1, 2, 1, 3, 2, 1]) await getUser(id);
