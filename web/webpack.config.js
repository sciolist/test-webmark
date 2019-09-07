const webpack = require('webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const glob = require('glob');
const path = require('path');

const RESULTS = glob.sync(path.join(__dirname, '../out/*.json')).map(p => path.basename(p, '.json'));

module.exports = {
    mode: process.env.NODE_ENV || 'development',
    context: __dirname,
    entry: './index',
    resolve: {
        extensions: ['.ts', '.tsx', '.js']
    },
    module: {
        rules: [
            {
                test: /\.tsx?$/,
                loader: 'babel-loader'
            },
            {
                test: /\.css$/,
                use: ['style-loader', 'css-loader?modules']
            }
        ]
    },
    plugins: [
        new HtmlWebpackPlugin({
            title: 'webmark results'
        }),
        new webpack.DefinePlugin({
            'process.env.RESULTS': JSON.stringify(JSON.stringify(RESULTS))
        })
    ]
}