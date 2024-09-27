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

function toggleDetails(skillId) {
  const details = document.getElementById(skillId);
  if (details.style.display === "block") {
      details.style.display = "none";
  } else {
      details.style.display = "block";
  }
}

// Select all skills with certification lists
const skills = document.querySelectorAll('.skills-list li');

skills.forEach(skill => {
    const skillName = skill.querySelector('.skill-name');
    const certificationList = skill.querySelector('.certification-list');

    // Only add event listeners if there is a certification list
    if (certificationList) {
        skillName.addEventListener('click', () => {
            // Toggle the display of the certification list
            const isVisible = certificationList.style.display === 'block';
            certificationList.style.display = isVisible ? 'none' : 'block';
        });
    }
});


// Wait for the document to be fully loaded
document.addEventListener("DOMContentLoaded", function () {
  // Get a reference to the element by its id
  const visitors_count = document.getElementById('visitors-count');

  const requestUrl = "https://api.fbrpinto.com/visitors"

  // Data to be sent in the request body
  const data = {};

  // Configuring the fetch request
  const requestOptions = {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  };

  fetch(
    requestUrl,
    requestOptions
  )
    .then((response) => {
      if (!response.ok) {
        throw new Error("Network response was not ok");
      }
      return response.json();
    })
    .then(data => {
        console.log(data.visitors);
        visitors_count.textContent += data.visitors.toString();
    })
    .catch((error) => {
      console.error("Fetch error:", error);
    });
});