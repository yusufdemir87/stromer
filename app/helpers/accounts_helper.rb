# frozen_string_literal: true

module AccountsHelper
  def display_name(account, **options)
    str = account.display_name.presence || account.username

    if options[:custom_emojify]
      prerender_custom_emojis(h(str), account.emojis)
    else
      str
    end
  end

  def acct(account)
    if account.local?
      "@#{account.acct}@#{site_hostname}"
    else
      "@#{account.pretty_acct}"
    end
  end

  def account_formatted_stat(value)
    number_to_human(value, precision: 3, strip_insignificant_zeros: true)
  end

  def account_description(account)
    posts = [
      account_formatted_stat(account.statuses_count),
      I18n.t('accounts.posts', count: account.statuses_count),
    ].join(' ')

    # AI creators show no follower numbers: they can be inflated and say nothing about quality.
    return [posts, account.note].join(' · ') if account.bot?

    prepend_str = [
      posts,

      [
        account_formatted_stat(account.following_count),
        I18n.t('accounts.following', count: account.following_count),
      ].join(' '),

      [
        account_formatted_stat(account.followers_count),
        I18n.t('accounts.followers', count: account.followers_count),
      ].join(' '),
    ].join(', ')

    [prepend_str, account.note].join(' · ')
  end
end
