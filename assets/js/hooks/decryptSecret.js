

import { OpenMLS } from '../openmls.js';
import { hexToBytes } from '../openmlsUtils.js';


const DecryptSecret = {
  async mounted() {
    console.log('[DecryptSecret] Hook mounted on', this.el);
    // Allow group id to be specified via data-group attribute
    const groupId = this.el.dataset.group;

    // Find all elements with data-ciphertext, or use self if present
    const targets = this.el.querySelectorAll('[data-ciphertext]');
    if (targets.length === 0 && this.el.dataset.ciphertext) {
      await this.decryptAndDisplay(this.el, groupId);
    } else {
      for (const el of targets) {
        await this.decryptAndDisplay(el, groupId);
      }
    }
  },

  async decryptAndDisplay(el, groupId) {
    const ciphertextHex = el.dataset.ciphertext || el.value || el.textContent;
    if (!ciphertextHex) return;
    console.log('[DecryptSecret] Decrypting for group', groupId, 'ciphertext:', ciphertextHex);
    const group = await OpenMLSGroup.createOrLoad(groupId, 'me');
    let cleartext = '';
    try {
      cleartext = group.decrypt(hexToBytes(ciphertextHex));
      console.log('[DecryptSecret] Decrypted value:', cleartext);
    } catch (e) {
      cleartext = '[Decryption failed]';
      console.error('[DecryptSecret] Decryption failed:', e);
    }
    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
      el.value = cleartext;
    } else {
      el.textContent = cleartext;
    }
  },
};

export default DecryptSecret;
