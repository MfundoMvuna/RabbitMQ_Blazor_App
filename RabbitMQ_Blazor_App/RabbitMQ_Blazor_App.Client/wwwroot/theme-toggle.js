(function(){
  const KEY = 'app-theme';
  const root = document.documentElement;
  function apply(theme){
    if(theme === 'dark') root.setAttribute('data-theme', 'dark');
    else root.removeAttribute('data-theme');
    localStorage.setItem(KEY, theme);
  }
  function init(){
    const saved = localStorage.getItem(KEY) || (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    apply(saved);
    // expose toggle
    window.toggleTheme = function(){
      const next = (root.getAttribute('data-theme') === 'dark') ? 'light' : 'dark';
      apply(next);
    }
  }
  init();
})();
