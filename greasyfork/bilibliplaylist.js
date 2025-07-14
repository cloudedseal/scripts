// ==UserScript==
// @name         bilibili playlist
// @namespace    https://greasyfork.org/
// @version      1.0
// @description  Logs playlist to the console when Bilibili's page is fully loaded.
// @author       cloudedseal
// @match        *://*.bilibili.com/*
// @grant        none
// @icon         https://static.hdslb.com/images/favicon.ico
// ==/UserScript==

(function () {
    'use strict';
     const prefix = 'you-get -c cookies.sqlite https://www.bilibili.com/video/'

    function getPlaylist() {
         // Step 1: Get all matching elements
        const items = document.getElementsByClassName("pod-item video-pod__item simple");
        // Step 2: Extract data-key values
        const dataKeys = [];
        for (const item of items) {
            // Use dataset to access data-key (preferred)
            dataKeys.push(prefix + item.dataset.key || "N/A"); // Fallback to "N/A" if missing
        }
        console.log(dataKeys.join("\n"))
    }

    // Check if the page is already loaded
    if (document.readyState === 'complete') {
        setTimeout(getPlaylist, 10 * 1000);
    } else {
        // Wait for the page to fully load
        window.addEventListener('load', setTimeout(getPlaylist, 10 * 1000));
    }
})();
