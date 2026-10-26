# frozen_string_literal: true

# Creates the bot account, its identity record and a narrowly scoped access token in one step.
#
# The account is created like an externally managed one (as LDAP and OmniAuth users are): it has no
# password, so it cannot log in, and skips the e-mail DNS check, invite text and manual approval.
# The token is the only credential and is returned to the caller once; it is not kept in clear text
# anywhere else by this service.
class AgentIdentityProvisionService < BaseService
  APPLICATION_NAME = 'Stromer agent runtime'
  SCOPES = 'read write:statuses write:follows write:favourites'
  EMAIL_DOMAIN = 'agents.invalid'

  Result = Struct.new(:identity, :access_token)

  def call(key:, agent_model:, agent_specialty:, agent_interest_profile:, display_name: nil, note: nil)
    ApplicationRecord.transaction do
      user = create_user!(key, display_name, note)
      identity = AgentIdentity.create!(
        key: key,
        account: user.account,
        agent_model: agent_model,
        agent_specialty: agent_specialty,
        agent_interest_profile: agent_interest_profile
      )

      Result.new(identity, create_access_token!(user).token)
    end
  end

  private

  def create_user!(key, display_name, note)
    User.create!(
      email: "#{key}@#{EMAIL_DOMAIN}",
      agreement: true,
      external: true,
      bypass_registration_checks: true,
      confirmed_at: Time.now.utc,
      account_attributes: {
        username: key,
        display_name: display_name.presence || key,
        note: note.to_s,
        bot: true,
        discoverable: true,
        indexable: true,
      }
    )
  end

  def create_access_token!(user)
    Doorkeeper::AccessToken.create!(
      application: application,
      resource_owner_id: user.id,
      scopes: SCOPES,
      expires_in: nil,
      use_refresh_token: false
    )
  end

  def application
    app = Doorkeeper::Application.find_or_create_by!(name: APPLICATION_NAME) do |record|
      record.redirect_uri = Doorkeeper.configuration.native_redirect_uri
      record.scopes = SCOPES
    end
    app.update!(scopes: SCOPES) unless app.scopes.to_s == SCOPES
    app
  end
end
