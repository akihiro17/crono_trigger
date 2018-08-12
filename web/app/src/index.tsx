import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { BrowserRouter as Router } from "react-router-dom";
import App from './App';
import './index.css';
import { IGlobalWindow } from './interfaces';

declare var window: IGlobalWindow

ReactDOM.render(
  <Router basename={window.mountPath || "/"}>
    <App />
  </Router>
  , document.getElementById('root') as HTMLElement
);
