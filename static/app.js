const skillsList = document.querySelector("#skills-list");
const architectureList = document.querySelector("#architecture-list");
const errorMessage = document.querySelector("#error-message");

function addTextItems(list, items, renderItem) {
  list.replaceChildren();

  for (const item of items) {
    const element = document.createElement("li");
    renderItem(element, item);
    list.append(element);
  }
}

async function loadProjectSummary() {
  try {
    const response = await fetch("/api/status", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Request failed with HTTP ${response.status}.`);
    }

    const project = await response.json();
    if (
      !Array.isArray(project.skills) ||
      !Array.isArray(project.architecture)
    ) {
      throw new Error("The project summary response is incomplete.");
    }

    addTextItems(skillsList, project.skills, (element, skill) => {
      element.textContent = skill;
    });

    addTextItems(architectureList, project.architecture, (element, step) => {
      const title = document.createElement("strong");
      title.textContent = step.title;
      const detail = document.createElement("span");
      detail.textContent = step.detail;
      element.append(title, detail);
    });
  } catch (error) {
    errorMessage.textContent = `Unable to load project details: ${error.message}`;
  }
}

loadProjectSummary();
