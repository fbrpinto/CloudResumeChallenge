describe('Resume navigation', () => {
  it('should navigate to different sections of the resume', () => {
      cy.visit('https://fbrpinto.com')
      
      cy.get('a[href="#about"]').click()
      cy.url().should('include', '#about')
      
      cy.get('a[href="#experience"]').click()
      cy.url().should('include', '#experience')

      cy.get('a[href="#education"]').click()
      cy.url().should('include', '#education')

      cy.get('a[href="#skills"]').click()
      cy.url().should('include', '#skills')

      cy.get('a[href="#interests"]').click()
      cy.url().should('include', '#interests')

      cy.get('a[href="#awards"]').click()
      cy.url().should('include', '#awards')
      
  })
})