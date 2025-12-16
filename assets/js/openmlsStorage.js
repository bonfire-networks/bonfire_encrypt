// openmlsStorage.js
// IndexedDB wrapper for OpenMLS group/session state


const DB_NAME = 'openmls-db';
const DB_VERSION = 2;
const STORES = ['groups', 'users'];

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (event) => {
      const db = event.target.result;
      for (const store of STORES) {
        if (!db.objectStoreNames.contains(store)) {
          db.createObjectStore(store, { keyPath: 'id' });
        }
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

// Generic helpers
async function saveState(store, id, state) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(store, 'readwrite');
    const objStore = tx.objectStore(store);
    objStore.put({ id, state });
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function loadState(store, id) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(store, 'readonly');
    const objStore = tx.objectStore(store);
    const req = objStore.get(id);
    req.onsuccess = () => resolve(req.result ? req.result.state : null);
    req.onerror = () => reject(req.error);
  });
}

async function deleteState(store, id) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(store, 'readwrite');
    const objStore = tx.objectStore(store);
    objStore.delete(id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

async function listStates(store) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(store, 'readonly');
    const objStore = tx.objectStore(store);
    const req = objStore.getAll();
    req.onsuccess = () => resolve(req.result.map(r => ({ id: r.id, state: r.state })));
    req.onerror = () => reject(req.error);
  });
}

// Group-specific
export function saveGroupState(id, state) {
  return saveState('groups', id, state);
}
export function loadGroupState(id) {
  return loadState('groups', id);
}
export function deleteGroupState(id) {
  return deleteState('groups', id);
}
export function listGroupStates() {
  return listStates('groups');
}

// User-specific (for key packages)
export function saveUserKeyPackage(userId, keyPackageHex) {
  return saveState('users', userId, { keyPackageHex });
}
export async function loadUserKeyPackage(userId) {
  const state = await loadState('users', userId);
  return state ? state.keyPackageHex : null;
}
