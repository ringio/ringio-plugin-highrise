#Setting up the necessary variables to start the service
#Defaults for site, tokens left blank in commit for security

if RAILS_ENV == 'test'
	RingioAPI::Base.site = 'http://newtesting.ringio.com/api-app/'
	RingioAPI::Base.user = 'apiauthtoken'
end

if RAILS_ENV == 'development'
	RingioAPI::Base.site = 'http://newtesting.ringio.com/api-app/'
	RingioAPI::Base.user = 'apiauthtoken'
end

if RAILS_ENV == 'production'
	RingioAPI::Base.site = 'http://dev.ringio.com'
	RingioAPI::Base.user = 'productionauthtoken'
end