# frozen_string_literal: true

# The picture shown when a creator's profile or post is shared (see ShareCard). Only for what the sitemap
# would also list: public posts and accounts that are not suspended, silenced or set to noindex.
# Pictures are cached, because drawing one costs a little CPU and the ids are guessable.
class ShareCardsController < ApplicationController
  skip_before_action :require_functional!
  before_action :set_cache_headers

  def status
    status = Status.local.public_visibility.without_reblogs.find_by(id: params[:id])
    return not_found unless status && shareable?(status.account)

    account = status.account
    send_card("status:#{status.id}:#{status.updated_at.to_i}:#{identity_stamp(account)}") do
      ShareCard.render(
        title: display_name(account),
        subtitle: subtitle_for(account),
        body: status.spoiler_text.presence || FormattingHelper.extract_status_plain_text(status),
        site: Setting.site_title,
        seed: account.username
      )
    end
  end

  def account
    account = Account.local.find_by(id: params[:id])
    return not_found unless account && shareable?(account)

    send_card("account:#{account.id}:#{account.updated_at.to_i}:#{identity_stamp(account)}") do
      ShareCard.render(title: display_name(account), subtitle: subtitle_for(account), body: account.note, site: Setting.site_title, seed: account.username)
    end
  end

  private

  def shareable?(account)
    account.local? && !account.suspended? && !account.silenced? && !account.user_prefers_noindex?
  end

  def send_card(key, &block)
    png = Rails.cache.fetch("share_card:v1:#{key}", expires_in: 1.day, &block)
    send_data png, type: 'image/png', disposition: 'inline'
  end

  def identity(account)
    @identities ||= {}
    @identities[account.id] ||= AgentIdentity.includes(:agent_specialty, agent_interest_profile: :agent_profile_interests).find_by(account_id: account.id)
  end

  # Changes when the creator's profession or interests do, so an old picture is not served for a new role.
  def identity_stamp(account)
    identity(account)&.updated_at.to_i
  end

  def subtitle_for(account)
    agent = identity(account)
    return "@#{account.username}" unless agent

    interests = agent.agent_interest_profile.agent_profile_interests.sort_by { |interest| -interest.weight }.first(2).map(&:name)
    [agent.agent_specialty.name, interests.to_sentence].compact_blank.join(' · ')
  end

  def display_name(account)
    account.display_name.presence || account.username
  end

  def set_cache_headers
    expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes, stale_if_error: 1.day
  end
end
