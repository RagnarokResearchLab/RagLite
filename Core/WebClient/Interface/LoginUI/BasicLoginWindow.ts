class BasicLoginWindow {
  parent: HTMLDivElement;
  container: HTMLDivElement;
  titleBar: HTMLDivElement;
  titleText: HTMLParagraphElement;
  contentPane: HTMLParagraphElement;
  footer: HTMLDivElement;
  loginButton: HTMLButtonElement;
  quitButton: HTMLButtonElement;

  constructor(parent: HTMLDivElement) {
    this.parent = parent;

    this.container = document.createElement("div");
    this.container.className = "window";
    this.container.id = "BasicLoginWindow";
    parent.appendChild(this.container);

    this.titleBar = document.createElement("div");
    this.titleBar.className = "window-title-bar";

    this.titleText = document.createElement("p");
    this.titleText.innerText = "Connect to Realm Server";
    this.titleBar.appendChild(this.titleText);

    this.contentPane = document.createElement("p");
    this.contentPane.className = "window-content";
    this.contentPane.innerText = "Selected Realm: http://localhost:9005";

    this.loginButton = document.createElement("button");
    this.loginButton.className = "button";
    this.loginButton.innerText = "Connect";

    this.quitButton = document.createElement("button");
    this.quitButton.className = "button";
    this.quitButton.innerText = "Quit";

    this.footer = document.createElement("div");
    this.footer.className = "window-footer";
    this.footer.appendChild(this.loginButton);
    this.footer.appendChild(this.quitButton);

    this.container.appendChild(this.titleBar);
    this.container.appendChild(this.contentPane);
    this.container.appendChild(this.footer);
  }
}

export default BasicLoginWindow;
