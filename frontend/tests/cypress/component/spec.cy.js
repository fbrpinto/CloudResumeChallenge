const websiteUrl = "http://localhost:5000/";

describe("Test Menu Navigation", () => {
  it("should navigate to different sections of the resume", () => {
    cy.visit(websiteUrl);

    cy.get('a[href="#about"]').click();
    cy.url().should("include", "#about");

    cy.get('a[href="#experience"]').click();
    cy.url().should("include", "#experience");

    cy.get('a[href="#education"]').click();
    cy.url().should("include", "#education");

    cy.get('a[href="#skills"]').click();
    cy.url().should("include", "#skills");

    cy.get('a[href="#projects"]').click();
    cy.url().should("include", "#projects");
  });
});
