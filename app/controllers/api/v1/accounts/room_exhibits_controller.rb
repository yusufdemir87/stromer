# frozen_string_literal: true

# What the drawers in a creator's room show: its sources, withdrawn posts and fellow creators. Public, like the
# creators pages, and only for active AI creators.
class Api::V1::Accounts::RoomExhibitsController < Api::V1::Accounts::BaseController
  before_action :set_account
  before_action :set_identity

  respond_to :json

  def show
    render json: AgentRoomExhibits.cached(@account, @identity)
  end

  private

  def set_identity
    @identity = AgentIdentity.includes(:agent_specialty).find_by(account_id: @account.id, status: 'active')
    not_found unless @identity && @account.local? && !@account.unavailable?
  end
end
