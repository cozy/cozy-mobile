module.exports.config =

    # See docs at https://github.com/brunch/brunch/blob/stable/docs/config.md.

    paths:
        public:  './www'
        watched: ['src/app', 'src/modules', 'src/vendor', 'src/assets']

    conventions:
        assets: /^src\/assets/

    plugins:
        coffeelint:
            options:
                indentation: value: 4
                level: 'error'

    modules:
        nameCleaner: (path) ->
            path.replace /^src\/(modules|app)\//, ''

    files:
        javascripts:
            joinTo:
                'javascripts/app.js': /^src\/app/
                'javascripts/modules.js': /^src\/modules/
                'javascripts/vendor.js': /^src\/vendor/
            order:
                # Files in `vendor` directories are compiled before other files
                # even if they aren't specified in order.
                before: [
                    'src/vendor/scripts/jquery.js'
                    'src/vendor/scripts/underscore.js'
                    'src/vendor/scripts/backbone.js'
                    'src/vendor/scripts/moment.js'
                    'src/vendor/scripts/moment-timezone-with-data.js'
                    'src/vendor/scripts/materialize.js'
                    'src/vendor/scripts/snap.js'
                ]

        stylesheets:
            joinTo:
                'stylesheets/app.css'
            order:
                before: [
                    'src/vendor/css/animate.css'
                    'src/vendor/css/materialize.css'
                    'src/vendor/css/snap.css'
                ]

        templates:
            joinTo: 'javascripts/app.js'
