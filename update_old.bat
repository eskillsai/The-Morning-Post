<script>
    async function loadArchives() {
        const repoOwner = "eskillsai";
        const repoName = "The-Morning-Post";
        const folderPath = "archives";
        const listElement = document.getElementById("archive-list");
        const loadingElement = document.getElementById("loading-msg");

        try {
            // This talks directly to GitHub's cloud servers to find your files!
            const response = await fetch(`https://github.com{repoOwner}/${repoName}/contents/${folderPath}`);
            const files = await response.json();

            // Find all daily files, ignore the index menu page, and show newest first
            const htmlFiles = files
                .filter(file => file.name.endsWith('.html') && file.name !== 'index.html')
                .reverse(); 

            if (htmlFiles.length === 0) {
                loadingElement.innerText = "No archived editions found yet.";
                return;
            }

            loadingElement.style.display = "none";

            htmlFiles.forEach(file => {
                // Cleans up the filename for a professional menu look
                let displayTitle = file.name.replace('.html', '').replace(/—/g, '-');

                const li = document.createElement("li");
                li.className = "edition-item";
                li.innerHTML = `
                    <a class="edition-link" href="./${encodeURIComponent(file.name)}">
                        <span>📰 ${displayTitle}</span>
                        <span class="date">Live on GitHub</span>
                    </a>
                `;
                listElement.appendChild(li);
            });
        } catch (error) {
            loadingElement.innerText = "Error syncing with GitHub. Please refresh.";
            console.error(error);
        }
    }
    loadArchives();
</script>
