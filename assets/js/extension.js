
window.addEventListener("error", (event) => {
	console.log("Error detected. Making sure the userkey is removed");
	var userkeyStashEl = document.getElementById("userkey-stash");
	if (userkeyStashEl) {
		userkeyStashEl.value = "";
	}
});

import EncryptSecret from "./hooks/encryptSecret";
import DecryptSecret from "./hooks/decryptSecret";
import EncryptionGroup from "./hooks/encryptionGroup";

let EncryptHooks = {
	EncryptSecret: EncryptSecret,
	DecryptSecret: DecryptSecret,
	EncryptionGroup: EncryptionGroup,
};

export { EncryptHooks };
