// tauri_offline_scripts.js
import { initOpenMLS } from './openmls/openmls.js';
import { EncryptHooks } from "./extension.js";

if (!window.liveSocket) {
    console.error("liveSocket not found on window. Make sure bonfire_live.js is loaded before tauri-local-bundle.js");
    window.EncryptHooks = EncryptHooks;
} else {
    console.log("liveSocket found on window, trying to extend hooks with EncryptHooks");
    Object.assign(window.liveSocket.hooks, EncryptHooks);
}

window.initOpenMLS = initOpenMLS;
