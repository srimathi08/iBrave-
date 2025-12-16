import { LightningElement, track } from 'lwc';
import QuadrobayLogo from '@salesforce/resourceUrl/QuadrobayLogo';

export default class MyVerticalNav extends LightningElement {

    quadrobayLogoUrl = QuadrobayLogo;
    
    @track activePage = 'home'; // Tracks the currently active navigation item
    @track isSidebarExpanded = false; // Controls the expansion state of the sidebar

    // Define navigation items with their labels and icons
    navItems = [
        { id: 'home', label: 'Home', icon: 'utility:home' },
        { id: 'onboarding', label: 'Onboarding', icon: 'utility:onboarding' },
        { id: 'timeTracker', label: 'Time Tracker', icon: 'utility:clock' },
        { id: 'attendance', label: 'Attendance', icon: 'utility:attendance' },
        { id: 'more', label: 'More', icon: 'utility:more' },
        { id: 'operations', label: 'Operations', icon: 'utility:settings' },
        { id: 'reports', label: 'Reports', icon: 'utility:report' }
    ];

    // Getter to dynamically apply CSS classes for sidebar expansion
    get sidebarClass() {
        let classes = 'slds-col app-sidebar';
        if (this.isSidebarExpanded) {
            classes += ' slds-size_1-of-1 slds-medium-size_1-of-5 slds-large-size_1-of-6 sidebar-expanded';
        } else {
            classes += ' slds-size_1-of-1 slds-medium-size_small slds-large-size_x-small sidebar-collapsed';
        }
        return classes;
    }

    // Getter to dynamically apply CSS classes for main content area based on sidebar state
    get mainContentClass() {
        let classes = 'slds-col slds-p-around_medium app-main-content';
        if (this.isSidebarExpanded) {
            classes += ' slds-size_1-of-1 slds-medium-size_4-of-5 slds-large-size_5-of-6 content-shifted';
        } else {
            classes += ' slds-size_1-of-1 slds-medium-size_large slds-large-size_xx-large content-full-width';
        }
        return classes;
    }

    // Getter to control visibility of navigation text
    get navTextClass() {
        return this.isSidebarExpanded ? 'slds-show' : 'slds-hide';
    }

    // Getters for conditional rendering of main content based on activePage
    get isHomePage() {
        return this.activePage === 'home';
    }
    get isOnboardingPage() {
        return this.activePage === 'onboarding';
    }
    get isTimeTrackerPage() {
        return this.activePage === 'timeTracker';
    }
    get isAttendancePage() {
        return this.activePage === 'attendance';
    }
    get isMorePage() {
        return this.activePage === 'more';
    }
    get isOperationsPage() {
        return this.activePage === 'operations';
    }
    get isReportsPage() {
        return this.activePage === 'reports';
    }

    /**
     * Handles navigation clicks.
     * Updates the active page and highlights the selected navigation item.
     * @param {Event} event The click event.
     */
    handleNavigation(event) {
        // Remove 'slds-is-active' class from all navigation items
        this.template.querySelectorAll('.slds-nav-vertical__action').forEach(item => {
            item.classList.remove('slds-is-active');
        });

        // Add 'slds-is-active' class to the clicked item
        event.currentTarget.classList.add('slds-is-active');

        // Update the activePage based on the data-id attribute of the clicked item
        this.activePage = event.currentTarget.dataset.id;
        
        // Optionally collapse sidebar on mobile after selection
        if (window.innerWidth < 768 && this.isSidebarExpanded) {
            this.isSidebarExpanded = false;
        }
        console.log(`Navigated to: ${this.activePage}`);
    }

    /**
     * Toggles the expansion state of the sidebar.
     */
    toggleSidebar() {
        this.isSidebarExpanded = !this.isSidebarExpanded;
    }

    /**
     * Example method for a button click in the main content.
     */
    handleCheckIn() {
        console.log('Check-In button clicked!');
        // Add your check-in logic here
    }
}