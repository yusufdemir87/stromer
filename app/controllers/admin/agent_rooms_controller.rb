# frozen_string_literal: true

module Admin
  # Where a person approves the rooms AI creators propose (see AgentRoom): the first room of every creator and
  # every room of a creator on public-record subjects. A proposal is shown in the same sandboxed frame as the
  # public room, so reading it is as safe as what visitors see.
  class AgentRoomsController < BaseController
    before_action :authorize_rooms
    before_action :set_room, except: :index
    before_action :drop_nonce, only: :preview

    content_security_policy(only: :preview) { |policy| RoomDocument.apply_policy(policy) }

    def index
      @rooms = AgentRoom.where(status: 'held').includes(agent_identity: [:account, :agent_specialty]).order(:created_at).page(params[:page]).per(10)
    end

    def preview
      response.headers['X-Frame-Options'] = 'SAMEORIGIN'
      response.headers['Cache-Control'] = 'private, no-store'
      render body: RoomDocument.render(@room.html, title: "#{@room.agent_identity.key} v#{@room.version}", lang: I18n.locale.to_s), content_type: 'text/html', layout: false
    end

    def publish
      return redirect_to(admin_agent_rooms_path, alert: t('admin.agent_rooms.not_held')) unless @room.status == 'held'

      @room.publish!
      redirect_to admin_agent_rooms_path, notice: t('admin.agent_rooms.published')
    end

    def reject
      return redirect_to(admin_agent_rooms_path, alert: t('admin.agent_rooms.not_held')) unless @room.status == 'held'

      @room.update!(status: 'rejected')
      redirect_to admin_agent_rooms_path, notice: t('admin.agent_rooms.rejected')
    end

    private

    def authorize_rooms
      authorize :agent_catalog, :update?
    end

    def set_room
      @room = AgentRoom.includes(agent_identity: :account).find(params[:id])
    end

    # The nonce is for style-src in the rest of the site; with it, browsers would ignore unsafe-inline here.
    def drop_nonce
      request.content_security_policy_nonce_generator = nil
    end
  end
end
