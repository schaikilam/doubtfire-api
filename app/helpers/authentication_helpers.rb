#
# The AuthenticationHelpers include functions to check if the user
# is authenticated and to fetch the current user.
#
# This is used by the grape api.
#
module AuthenticationHelpers
  def warden
    env['warden']
  end

  module_function

  #
  # Checks if the requested user is authenticated.
  # Reads details from the params fetched from the caller context.
  #
  def authenticated?
    # Check warden -- authenticate using DB or LDAP etc.
    return true if warden.authenticated?

    # Check for auth token parameter
    if params.present? && params[:auth_token].present?
      # Get the token and the user - if there is a token
      token = AuthToken.find_by_auth_token(params[:auth_token])
      user_by_token = token.user unless token.nil?
    end

    # Check user by token
    if user_by_token.present?
      # Non-expired token
      return true if token.auth_token_expiry > Time.zone.now
      # Token is timed out - destroy it
      token.destroy!
      # Time out this token
      error!({ error: 'Authentication token expired.' }, 419)
    else
      # Add random delay then fail
      sleep((200 + rand(200)) / 1000.0)
      error!({ error: 'Could not authenticate with token. Token invalid.' }, 419)
    end
  end

  #
  # Get the current user either from warden or from the token
  #
  def current_user
    warden.user || AuthToken.user_for_token(params[:auth_token])
  end

  #
  # Add the required auth_token to each of the routes for the provided
  # Grape::API.
  #
  def add_auth_to(service)
    service.routes.each do |route|
      options = route.instance_variable_get('@options')
      next if options[:params]['auth_token']
      options[:params]['auth_token'] = {
        required: true,
        type:     'String',
        desc:     'Authentication token'
      }
      options[:params]['username'] = {
        required: true,
        type:     'String',
        desc:     'user username'
      }
    end
  end

  #
  # Returns true iff using AAF devise auth strategy
  #
  def aaf_auth?
    Doubtfire::Application.config.auth_method == :aaf
  end

  #
  # Returns true iff using LDAP devise auth strategy
  #
  def ldap_auth?
    Doubtfire::Application.config.auth_method == :ldap
  end

  #
  # Returns true iff using database devise auth strategy
  #
  def db_auth?
    Doubtfire::Application.config.auth_method == :database
  end
end
