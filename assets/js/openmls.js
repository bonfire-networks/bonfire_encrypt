// openmls.js
// Abstractions for OpenMLS group/session management using WASM
// Assumes openmls_wasm.js is loaded and available

// Example usage:
//   const group = await OpenMLSGroup.createOrLoad('my-group-id', 'me');
//   const ciphertext = group.encrypt('hello');
//   const plaintext = group.decrypt(ciphertext);


import * as Storage from './openmlsStorage.js';
import { getOrCreateUserKeyPackage } from './openmlsUser.js';

let openmlsWasm = null;
let Provider, Identity, Group, KeyPackage, RatchetTree;

export async function initOpenMLS() {
  if (!openmlsWasm) {

    if (window.__openmls_wasm) {
      openmlsWasm = await import('../../../../priv/static/assets/openmls/openmls_wasm.js');
      if (openmlsWasm.default) {
        console.log('Initializing OpenMLS WASM from preloaded binary');
        // load from preloaded global (e.g., Tauri bundle)
        await openmlsWasm.default(window.__openmls_wasm);
      } else {
        console.error('OpenMLS WASM module does not have default export for initialization');
        return;
      }
    } else if (typeof window.fetch === 'function') {
      // TODO: only load if user opts-in for less-secure remote JS/WASM loading
      console.log('Initializing OpenMLS WASM by fetching it');
      openmlsWasm = await import('../../../../priv/static/assets/openmls/openmls_wasm.js');
      if (openmlsWasm.default) {
        await openmlsWasm.default('/assets/openmls/openmls_wasm_bg.wasm');
      }  else {
          console.error('OpenMLS WASM module does not have default export for initialization');
          return;
      }
    } else {
      console.error('OpenMLS WASM module could not be loaded');
      return;
    }
    
    Provider = openmlsWasm.Provider;
    Identity = openmlsWasm.Identity;
    Group = openmlsWasm.Group;
    KeyPackage = openmlsWasm.KeyPackage;
    RatchetTree = openmlsWasm.RatchetTree;
  }
  return openmlsWasm;
}

export class OpenMLS {
  constructor({ id, identity, group, provider }) {
    this.id = id;
    this.identity = identity;
    this.group = group;
    this.provider = provider;
  }

  static async createOrLoad(id, userLabel = 'me', lvHook = null) {
    await initOpenMLS();
    let state = await Storage.loadGroupState(id);
    // Use openmlsUser.js for persistent user identity and key package
    const { provider, identity } = await getOrCreateUserKeyPackage(lvHook, userLabel);
    let group;
    // For now, always create a new group (no serialization of group state)
    // You can extend this to use ratchet tree/welcome serialization as in the demo
    group = Group.create_new(provider, identity, id);
    // Optionally, persist ratchet tree or other serializable state here
    return new OpenMLSGroup({ id, identity, group, provider });
  }

  async save() {
    // No-op for now; implement ratchet tree/welcome serialization if needed
    // Example: await Storage.saveGroupState(this.id, { ... });
  }

  encrypt(plaintext) {
    const msg = new TextEncoder().encode(plaintext);
    const ciphertext = this.group.create_message(this.provider, this.identity, msg);
    return Array.from(ciphertext); // Uint8Array to Array for storage/transmission
  }

  decrypt(ciphertextArr) {
    const ciphertext = new Uint8Array(ciphertextArr);
    const plaintext = this.group.process_message(this.provider, ciphertext);
    return new TextDecoder().decode(plaintext);
  }

  // Add more group management methods as needed (addMember, export/import, etc.)
}
