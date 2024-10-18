// Define the URLs for the website and API
const websiteUrl = "http://localhost:5000/"; // Local development URL for the website
const APIUrl = "https://api.fbrpinto.com/visitors"; // API endpoint for visitor data

// Describe block for testing menu navigation on the website
describe("Test Menu Navigation", () => {
  it("should navigate to different sections of the resume", () => {
    cy.visit(websiteUrl); // Visit the website

    // Click on the 'About' section link and check the URL
    cy.get('a[href="#about"]').click();
    cy.url().should("include", "#about"); // Verify that the URL contains '#about'

    // Click on the 'Experience' section link and check the URL
    cy.get('a[href="#experience"]').click();
    cy.url().should("include", "#experience"); // Verify that the URL contains '#experience'

    // Click on the 'Education' section link and check the URL
    cy.get('a[href="#education"]').click();
    cy.url().should("include", "#education"); // Verify that the URL contains '#education'

    // Click on the 'Skills' section link and check the URL
    cy.get('a[href="#skills"]').click();
    cy.url().should("include", "#skills"); // Verify that the URL contains '#skills'

    // Click on the 'Projects' section link and check the URL
    cy.get('a[href="#projects"]').click();
    cy.url().should("include", "#projects"); // Verify that the URL contains '#projects'
  });
});

// Describe block for testing the API, Lambda function, and DynamoDB
describe("Test API, Lambda function, and DynamoDB", () => {
  it("should return the correct status codes", () => {
    // Test GET request and expect a 404 status code
    cy.request({
      method: "GET",
      url: APIUrl,
      failOnStatusCode: false, // Prevent Cypress from failing the test on non-2xx status codes
    }).then((response) => {
      expect(response.status).to.eq(404); // Assert that the status is 404
    });

    // Test PUT request and expect a 404 status code
    cy.request({
      method: "PUT",
      url: APIUrl,
      failOnStatusCode: false,
    }).then((response) => {
      expect(response.status).to.eq(404); // Assert that the status is 404
    });

    // Test DELETE request and expect a 404 status code
    cy.request({
      method: "DELETE",
      url: APIUrl,
      failOnStatusCode: false,
    }).then((response) => {
      expect(response.status).to.eq(404); // Assert that the status is 404
    });

    // Test POST request and expect a 200 status code
    cy.request("POST", APIUrl).then((response) => {
      expect(response.status).to.eq(200); // Assert that the status is 200
    });
  });
});

// Describe block for testing the visitors count in the DOM
describe("Test Visitors Count in the DOM", () => {
  it("should update the visitors count in the DOM", () => {
    let previousCount = 0; // Variable to hold the previous visitor count

    cy.intercept("POST", APIUrl).as("postRequest"); // Intercept POST requests to the API

    // Visit the page
    cy.visit(websiteUrl);

    // Wait to guarantee the website was updated
    cy.wait(1000); // Wait for 1 second

    // Assert that the POST request was made successfully
    cy.wait("@postRequest").its("response.statusCode").should("eq", 200);

    // Check the visitors count in the DOM
    cy.get("#visitors-count")
      .should("exist") // Ensure the element exists
      .then(($element) => {
        const text = $element.text(); // Get the text content of the element
        previousCount = parseInt(text.match(/\d+/)[0]); // Extract and convert the count to a number
        expect(previousCount).to.be.a("number"); // Assert that it is a number
      });

    // Revisit the website to check for updated visitor count
    cy.visit(websiteUrl);

    // Wait to guarantee the website was updated
    cy.wait(1000); // Wait for 1 second

    // Assert that the POST request was made successfully
    cy.wait("@postRequest").its("response.statusCode").should("eq", 200);

    // Assert the updated state of the DOM after revisiting and API call
    cy.get("#visitors-count")
      .should("exist") // Ensure the element exists
      .then(($element) => {
        const text = $element.text(); // Get the text content of the element
        const currentCount = parseInt(text.match(/\d+/)[0]); // Extract and convert the current count to a number
        expect(currentCount).to.be.a("number"); // Assert that it is a number
        expect(currentCount).to.be.greaterThan(previousCount); // Ensure the current count is greater than the previous count
      });
  });
});
