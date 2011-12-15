#Setting up the necessary variables to start the service
#Defaults for site, tokens left blank in commit for security

:group => :test do 
	RingioAPI::Base.site = 'http://newtesting.ringio.com/api-app/'
	RingioAPI::Base.user = 'apiauthtoken'
end


:group => :development do
	RingioAPI::Base.site = 'http://newtesting.ringio.com/api-app/'
	RingioAPI::Base.user = 'apiauthtoken'
end

:group => :production do
	RingioAPI::Base.site = 'http://dev.ringio.com'
	RingioAPI::Base.user = 'productionauthtoken'
end