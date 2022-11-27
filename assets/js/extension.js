
import Events from "./events"
import ShowPassphraseAfterCreate from "./hooks/showPassphraseAfterCreate"

let EncryptHooks = {
  ShowPassphraseAfterCreate: ShowPassphraseAfterCreate
}

window.addEventListener("error", (event) => {
  console.log("Error detected. Making sure the userkey is removed");
  var userkeyStashEl = document.getElementById("userkey-stash");
  if (userkeyStashEl) {
    userkeyStashEl.value = ""
  }
});

window.addEventListener("live-secret:clipcopy", (event) => {
  if ("clipboard" in navigator) {
    const text = event.target.value;
    if (text == "") {

    } else {
      navigator.clipboard.writeText(text);
      event.target.classList.add("flash");
      setTimeout(() => {
        event.target.classList.remove("flash");
      }, 200);

    }
  } else {
    alert("Sorry, your browser does not support clipboard copy.");
  }
});

window.addEventListener("live-secret:clipcopy-instructions", (event) => {
  //console.log("Generating instructions...");
  var userkeyStashEl = document.getElementById("userkey-stash");

  var flashUserkey = true;

  var passphrase = userkeyStashEl.value;
  if (userkeyStashEl.value === "") {
    passphrase = "<Admin must provide the passphrase>";
    flashUserkey = false;
  }

  var oobUrlEl = document.getElementById("oob-url");
  var instructions = `Hi, I'd like to share an encrypted message with you.
1. Open this link in your browser:
\`\`\`
`+ oobUrlEl.value + `
\`\`\`
2. When prompted, enter the following passphrase:
\`\`\`
`+ passphrase + `
\`\`\``;

  if ("clipboard" in navigator) {
    navigator.clipboard.writeText(instructions);
    oobUrlEl.classList.add("flash");
    if (flashUserkey) {
      userkeyStashEl.classList.add("flash");
    }

    setTimeout(() => {
      oobUrlEl.classList.remove("flash");
      userkeyStashEl.classList.remove("flash");
    }, 200);
  } else {
    alert("Sorry, your browser does not support clipboard copy.");
  }

});

window.addEventListener("live-secret:select-choice", (event) => {
  event.target.value = event.detail.value
  event.target.dispatchEvent(
    new Event("input", { bubbles: true })
  )
});

window.addEventListener("live-secret:create-secret", Events.CreateSecret);
window.addEventListener("live-secret:decrypt-secret", Events.DecryptSecret);

export { EncryptHooks };
