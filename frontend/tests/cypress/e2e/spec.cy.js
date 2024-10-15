const websiteUrl = "http://localhost:5000/";
const APIUrl = "https://api.fbrpinto.com/visitors";

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

describe("Test API, Lambda function, and DynamoDB", () => {
  it("should return the correct status codes", () => {
    cy.request({
      method: "GET",
      url: APIUrl,
      failOnStatusCode: false,
    }).then((response) => {
      expect(response.status).to.eq(404);
    });

    cy.request({
      method: "PUT",
      url: APIUrl,
      failOnStatusCode: false,
    }).then((response) => {
      expect(response.status).to.eq(404);
    });

    cy.request({
      method: "DELETE",
      url: APIUrl,
      failOnStatusCode: false,
    }).then((response) => {
      expect(response.status).to.eq(404);
    });

    cy.request("POST", APIUrl).then((response) => {
      expect(response.status).to.eq(200);
    });
  });
});

describe("Test Visitors Count in the DOM", () => {
  it("should update the visitors count in the DOM", () => {
    let previousCount = 0;

    cy.intercept("POST", APIUrl).as("postRequest");

    // Visit the page
    cy.visit(websiteUrl);

    // Wait to guarantee the webiste was updated
    cy.wait(1000);

    // Assert that the POST request was made
    cy.wait("@postRequest").its("response.statusCode").should("eq", 200);

    cy.get("#visitors-count")
      .should("exist")
      .then(($element) => {
        const text = $element.text();
        previousCount = parseInt(text.match(/\d+/)[0]);
        expect(previousCount).to.be.a("number");
      });

    // Revisit the website
    cy.visit(websiteUrl);

    // Wait to guarantee the webiste was updated
    cy.wait(1000);

    // Assert that the POST request was made
    cy.wait("@postRequest").its("response.statusCode").should("eq", 200);

    // Assert the updated state of the DOM after revisiting and API call
    cy.get("#visitors-count")
      .should("exist")
      .then(($element) => {
        const text = $element.text();
        const currentCount = parseInt(text.match(/\d+/)[0]);
        expect(currentCount).to.be.a("number");
        expect(currentCount).to.be.greaterThan(previousCount);
      });
  });
});