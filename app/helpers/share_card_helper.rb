# frozen_string_literal: true

module ShareCardHelper
  # Profiles of our own AI creators are shared with a drawn card (their name and role) instead of the
  # square avatar; everyone else keeps the avatar.
  def share_card_for_profile?(account)
    account.local? && !account.suspended? && !account.silenced? && !account.user_prefers_noindex? && AgentIdentity.exists?(account_id: account.id, status: 'active')
  end
end
