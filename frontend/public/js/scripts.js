/*!
 * Start Bootstrap - Resume v7.0.6 (https://startbootstrap.com/theme/resume)
 * Copyright 2013-2023 Start Bootstrap
 * Licensed under MIT (https://github.com/StartBootstrap/startbootstrap-resume/blob/master/LICENSE)
 */
//
// Scripts
//

window.addEventListener("DOMContentLoaded", (event) => {
  // Activate Bootstrap scrollspy on the main nav element
  const sideNav = document.body.querySelector("#sideNav");
  if (sideNav) {
    new bootstrap.ScrollSpy(document.body, {
      target: "#sideNav",
      rootMargin: "0px 0px -40%",
    });
  }

  // Collapse responsive navbar when toggler is visible
  const navbarToggler = document.body.querySelector(".navbar-toggler");
  const responsiveNavItems = [].slice.call(
    document.querySelectorAll("#navbarResponsive .nav-link")
  );
  responsiveNavItems.map(function (responsiveNavItem) {
    responsiveNavItem.addEventListener("click", () => {
      if (window.getComputedStyle(navbarToggler).display !== "none") {
        navbarToggler.click();
      }
    });
  });
});


// Wait for the document to be fully loaded
document.addEventListener("DOMContentLoaded", function () {
  // Get a reference to the <h1> element by its id
  // const visitors_count = document.getElementById('visitors-count');

  // Data to be sent in the request body
  const data = {};

  // Configuring the fetch request
  const requestOptions = {
    method: "POST",
    headers: {
      "Content-Type": "application/json", // Specify content type as JSON
    },
    body: JSON.stringify(data), // Convert data to JSON string
  };

  fetch(
    "https://x58exz4g03.execute-api.eu-west-1.amazonaws.com/dev/visitors",
    requestOptions
  )
    .then((response) => {
      if (!response.ok) {
        throw new Error("Network response was not ok");
      }
      return response.json();
    })
    // .then(data => {
    //     // console.log(data.visitors);
    //     // visitors_count.textContent += data.visitors.toString();
    //     console.log(data);
    // })
    .catch((error) => {
      console.error("Fetch error:", error);
    });
});
