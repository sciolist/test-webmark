const webpack = require('webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const glob = require('glob');
const path = require('path');
const DIRECTORY = path.resolve(__dirname, process.env.DIRECTORY || '../out');

module.exports = {
    mode: process.env.NODE_ENV || 'development',
    context: __dirname,
    entry: './index',
    resolve: {
        extensions: ['.ts', '.tsx', '.js']
    },
    output: {
        path: path.resolve(DIRECTORY, 'web')
    },
    module: {
        rules: [
            {
                test: /\.tsx?$/,
                use: {
                  loader: 'babel-loader',
                  options: {
                    rootMode: 'upward'
                  }
                }
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
            'process.env.DIRECTORY': JSON.stringify(DIRECTORY)
        })
    ]
}