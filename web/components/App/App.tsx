import { h, Component } from 'preact';
import { observer } from 'iaktta.preact';
import { ListTests } from '../ListTests/ListTests';

@observer
export class App extends Component {
    render() {
        return <ListTests />
    }
}