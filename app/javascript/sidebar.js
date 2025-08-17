// Sidebar toggle functionality
function initializeSidebar() {
  const sidebar = document.getElementById('sidebar');
  const toggleBtn = document.getElementById('toggle-sidebar');
  
  if (!sidebar || !toggleBtn) return;
  
  // Remove any existing click listeners to prevent duplicates
  const newToggleBtn = toggleBtn.cloneNode(true);
  toggleBtn.parentNode.replaceChild(newToggleBtn, toggleBtn);
  
  // Check if mobile
  function isMobile() {
    return window.innerWidth <= 768;
  }
  
  // Load saved state from localStorage (only for desktop)
  if (!isMobile()) {
    const isCollapsed = localStorage.getItem('sidebarCollapsed') === 'true';
    if (isCollapsed) {
      collapseSidebar();
    }
  }
  
  newToggleBtn.addEventListener('click', function(e) {
    e.preventDefault();
    console.log('Toggle button clicked'); // Debug log
    if (isMobile()) {
      toggleMobileSidebar();
    } else {
      if (sidebar.classList.contains('sidebar-collapsed')) {
        expandSidebar();
      } else {
        collapseSidebar();
      }
    }
  });
  
  function collapseSidebar() {
    console.log('Collapsing sidebar'); // Debug log
    sidebar.classList.add('sidebar-collapsed');
    localStorage.setItem('sidebarCollapsed', 'true');
  }
  
  function expandSidebar() {
    console.log('Expanding sidebar'); // Debug log
    sidebar.classList.remove('sidebar-collapsed');
    localStorage.setItem('sidebarCollapsed', 'false');
  }
  
  function toggleMobileSidebar() {
    sidebar.classList.toggle('sidebar-mobile-open');
  }
}

// Initialize on both DOMContentLoaded and turbo:load
document.addEventListener('DOMContentLoaded', initializeSidebar);
document.addEventListener('turbo:load', initializeSidebar);