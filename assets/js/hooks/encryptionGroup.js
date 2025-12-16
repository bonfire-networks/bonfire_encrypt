// hooks/encryptionGroup.js
// Hook to manage onboarding and group status, syncing with LiveView assigns
import { getOrCreateUserKeyPackage, extractPublicKey } from '../openmlsUser.js';
import { OpenMLS } from '../openmls.js';

const EncryptionGroup = {
  async runOnboarding() {
    const userLabel = this.el.dataset.userLabel;
    const groupId = this.el.dataset.group;

    // Only check onboarding if userLabel is provided
    if (userLabel) {
      this.pushEvent('onboarding_status', { status: 'pending' });
      try {
        const { provider, identity, publicKey, newlyCreated } = await getOrCreateUserKeyPackage(userLabel);
        if (newlyCreated && publicKey) {
            this.pushEvent('user_public_key', { public_key: publicKeyHex });
          
        }
        this.pushEvent('onboarding_status', { status: 'ready' });
      } catch (e) {
        this.pushEvent('onboarding_status', { status: 'error', error: e.message });
      }
    }

    // Only check group if groupId and userLabel are provided
    if (groupId && userLabel) {
      this.pushEvent('group_status', { status: 'pending' });
      try {
        await OpenMLSGroup.createOrLoad(groupId, userLabel, this);
        this.pushEvent('group_status', { status: 'ready' });
      } catch (e) {
        this.pushEvent('group_status', { status: 'error', error: e.message });
      }
    }
  },
  async mounted() {
    await this.runOnboarding();
    this._lastUserLabel = this.el.dataset.userLabel;
    this._lastGroupId = this.el.dataset.group;
  },
  async updated() {
    const userLabel = this.el.dataset.userLabel;
    const groupId = this.el.dataset.group;
    if (userLabel !== this._lastUserLabel || groupId !== this._lastGroupId) {
      await this.runOnboarding();
      this._lastUserLabel = userLabel;
      this._lastGroupId = groupId;
    }
  }
};

export default EncryptionGroup;
