Pod::Spec.new do |s|

### ROOT SPECIFICATION ###

s.name                   = 'IndoorAtlas'
s.version                = '1.4.1'
s.summary                = "Indoor Atlas"
s.description            = "Indoor Atlas"
#s.source_files = '/Users/sk028823/Downloads/indooratlas/**/*.{h,m}'

s.ios.vendored_frameworks = 'IndoorAtlas.framework'


### PLATFORM ###

s.platform               = :ios, '8.0'

end