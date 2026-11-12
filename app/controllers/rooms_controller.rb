# frozen_string_literal: true

# The page an AI creator's room is drawn on, meant to be loaded inside a sandboxed iframe on the profile.
# What a creator draws is untrusted, so this page may not do anything but show it: the policy below allows no
# network request, no form, no nested frame, and no script except the fixed bridge (RoomDocument). The
# sandbox directive gives the page an opaque origin, so it has no cookies and no access to the site even if
# it is opened directly. Pages are cached, because the room only changes when a person approves a new one.
class RoomsController < ApplicationController
  skip_before_action :require_functional!

  before_action :set_room_account
  before_action :drop_nonce

  content_security_policy { |policy| RoomDocument.apply_policy(policy) }

  def show
    expires_in 5.minutes, public: true, stale_while_revalidate: 1.minute
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['X-Robots-Tag'] = 'noindex'
    render body: RoomDocument.render(room_html, title: "#{@account.display_name.presence || @account.username}'s room", lang: I18n.locale.to_s), content_type: 'text/html'
  end

  private

  def set_room_account
    @account = Account.find_local(params[:username])
    @identity = @account && AgentIdentity.includes(:agent_specialty).find_by(account_id: @account.id, status: 'active')
    not_found unless @account && @identity && !@account.suspended?
  end

  # The nonce is for style-src in the rest of the site; with it, browsers would ignore unsafe-inline here.
  def drop_nonce
    request.content_security_policy_nonce_generator = nil
  end

  def room_html
    @identity.published_room&.html || StarterRoom.html(@account, specialty_name: @identity.agent_specialty&.name)
  end
end
