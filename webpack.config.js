var path = require('path');
var HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
  target: 'electron',
  context: path.join(__dirname, 'src'),
  entry: {
      electron: './electron-start.js',
      main: './shared/main.js',
      listwindow: './shared/listwindow.js'
  },
  output: {
    path: path.join(__dirname, 'dist'),
    publicPath: '/dist',
    filename: '[name].js'
  },
  resolve: {
    extensions: ['.js', '.elm']
  },
  module: {
    rules: [
      {
        test: /\.html$/,
        use : { loader: 'file-loader' }
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: {
          loader: 'elm-webpack-loader',
          options: {verbose: true, warn: true}
        }
      },
      {
        test: require.resolve("textarea-autosize"),
        use: {
          loader: 'imports-loader',
          options: {jQuery : 'jquery'}
        }
      }
    ]
  },
  externals: {
    pouchdb: 'require(\'pouchdb\')'
  },
  devtool: 'source-map',
  plugins: [
    new HtmlWebpackPlugin({
      template: './static/index.html',
      chunks: ['main']
    }),
    new HtmlWebpackPlugin({
      template: './static/list.html',
      chunks: ['listwindow'],
      filename: 'list.html'
    })
  ]
}
