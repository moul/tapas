path = require 'path'

module.exports =
    dirname: process.cwd() || __dirname
    dirs: [process.cwd(), __dirname, path.join(__dirname, '..')]
    port: 3000
    debug: false
    cookie_secret: null
    session_secret: null
    session: true
    cookie: true
    stylus: true
    connect_assets: true
    hogan: true
    less: false
    compress: true
    cache: true
    viewEngine: 'jade' #hjs
    staticMaxAge: 86400
    locals:
        title: ''
        site_name: 'Tapas'
        description: ""
        css_libraries: []
        js_libraries: []
        use:
            fontawesome: true
            bootstrap:
                responsive: false
                navbar:
                    fixed: false
                fixedNavbar: false
                fluid: false
                collapsibleNavbar: false
            user:
                navbar: false
        menus:
            navbar:
                '/':
                    title: 'Home'
            primary:
                '/':
                    title: 'Home'
                '/login':
                    title: 'Login'
                '/register':
                    title: 'Register'
                '/logout':
                    title: 'Logout'
        regions:
            #left:
            #navbar:
            #content:
            #left:
            #right:
            footer:
                'copyright': '<p>Copyright 2012</p>'
                'backToTop': '<p class="pull-right"><a href="#">Back to top</a></p>'
        grid:
            size: 12
            content: 12
            left: 3
            right: 3
        classes:
            content: []
            left: []
            right: []
    viewOptions:
        layout: false
        pretty: false
        complexNames: true
    ksAppConfigure: true
