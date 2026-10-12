import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './styles.css';

class AppBoundary extends React.Component<{children: React.ReactNode}, {error: string | null}> {
  state = { error: null as string | null };
  static getDerivedStateFromError(error: Error) {
    return { error: error?.message || 'Unbekannter Renderfehler' };
  }
  componentDidCatch(error: Error) {
    console.error('CLUBHOUSE konnte nicht gerendert werden:', error);
  }
  render() {
    if (this.state.error) {
      return <div style={{minHeight:'100vh',display:'grid',placeItems:'center',padding:24,boxSizing:'border-box',background:'#080e0a',color:'#edf5ee',fontFamily:'system-ui,sans-serif'}}>
        <div style={{maxWidth:560,padding:24,border:'1px solid #8b3f3f',borderRadius:14,background:'#15100f'}}>
          <h1 style={{color:'#ffb6a8'}}>CLUBHOUSE konnte nicht starten</h1>
          <p>Die Seite ist erreichbar, aber beim Anzeigen der App ist ein Fehler aufgetreten:</p>
          <pre style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere',color:'#ffd5cd'}}>{this.state.error}</pre>
          <p>Bitte sende genau diesen Fehlertext, damit ich den Fehler gezielt beheben kann.</p>
          <button onClick={() => window.location.reload()} style={{padding:'10px 14px',borderRadius:8,border:0,cursor:'pointer'}}>Neu laden</button>
        </div>
      </div>;
    }
    return this.props.children;
  }
}

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`).catch(error => console.warn('Service Worker nicht verfügbar:', error));
  });
}
createRoot(document.getElementById('root')!).render(<React.StrictMode><AppBoundary><App /></AppBoundary></React.StrictMode>);
