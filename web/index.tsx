import './index.css';
import { h, render } from 'preact';
import { App } from './components/App/App';
const div = document.createElement('div');
document.body.appendChild(div);
render(<App />, div);
