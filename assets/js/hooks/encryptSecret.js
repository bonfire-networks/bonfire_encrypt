// hooks/encryptSecret.js
// Generic hook to encrypt marked fields in any form before forwarding to a specified LV event
import { OpenMLS } from '../openmls/openmls.js';
import { bytesToHex } from '../openmls/openmlsUtils.js';

const EncryptSecret = {
  async mounted() {
    console.log('[EncryptSecret] Hook mounted on', this.el);
    this.el.addEventListener('submit', async (event) => {
      event.preventDefault();
      event.stopPropagation(); 

      // Get config from data attributes
      const encryptFields = (this.el.dataset.encryptFields || '').split(',').map(f => f.trim()).filter(Boolean);
      const groupId = this.el.dataset.group;
      const forwardEvent = this.el.dataset.forwardEvent || 'create';

      console.log('[EncryptSecret] Submitting form. Fields:', encryptFields, 'Group:', groupId, 'Forward event:', forwardEvent);

      // Load or create group
      const group = await OpenMLSGroup.createOrLoad(groupId, 'me');
      console.log('[EncryptSecret] Group loaded:', group);

      // Build payload with encrypted fields
      const payload = {};
      for (const field of encryptFields) {
        const input = this.el.querySelector(`[name="${field}"]`);
        if (input && input.value) {
          console.log(`[EncryptSecret] Encrypting field `, field, 'value:', input.value);
          const ciphertextBytes = group.encrypt(input.value);
          payload[field] = bytesToHex(ciphertextBytes);
          console.log(`[EncryptSecret] Encrypted value (hex):`, payload[field]);
        }
      }
      await group.save();
      console.log('[EncryptSecret] Group state saved');

      // Add creator_key (sender's public key)
      if (group.identity && typeof group.identity.key_package === 'function') {
        const keyPkg = group.identity.key_package(group.provider);
        if (keyPkg && typeof keyPkg.to_bytes === 'function') {
          payload.creator_key = bytesToHex(keyPkg.to_bytes());
          console.log('[EncryptSecret] Added creator_key:', payload.creator_key);
        }
      }

      // Optionally add other form fields (e.g., expires_at)
      const expiresInput = this.el.querySelector('[name="secret[expires_at]"]');
      if (expiresInput && expiresInput.value) {
        payload.expires_at = expiresInput.value;
      }

      // Send event to LiveView
      this.pushEvent(forwardEvent, payload);
      console.log('[EncryptSecret] Sent pushEvent:', forwardEvent, payload);
    });
  },
};

export default EncryptSecret;
