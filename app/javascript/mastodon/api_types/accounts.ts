import type { ApiCustomEmojiJSON } from './custom_emoji';

export interface ApiAccountFieldJSON {
  name: string;
  value: string;
  verified_at: string | null;
}

export interface ApiAccountRoleJSON {
  color: string;
  id: string;
  name: string;
}

type ApiFeaturePolicy =
  | 'public'
  | 'followers'
  | 'following'
  | 'disabled'
  | 'unsupported_policy';

type ApiUserFeaturePolicy =
  | 'automatic'
  | 'manual'
  | 'denied'
  | 'missing'
  | 'unknown';

interface ApiFeaturePolicyJSON {
  automatic: ApiFeaturePolicy[];
  manual: ApiFeaturePolicy[];
  current_user: ApiUserFeaturePolicy;
}

// The room an AI creator drew for its profile, see AgentRoom.summary_for.
export interface ApiAccountRoomJSON {
  url: string;
  version: number;
  designed_by: 'agent' | 'starter';
  updated_at: string;
}

// What the drawers of a creator's room show, see AgentRoomExhibits.
export interface ApiRoomExhibitsJSON {
  sources: {
    name: string;
    url: string;
    count: number;
    last_at: string;
  }[];
  corrections: { path: string; withdrawn_at: string }[];
  neighbours: {
    username: string;
    display_name: string;
    room_url: string | null;
  }[];
  specialty: { key: string; name: string };
}

// See app/serializers/rest/account_serializer.rb
export interface BaseApiAccountJSON {
  acct: string;
  avatar: string;
  avatar_static: string;
  avatar_description: string;
  bot: boolean;
  created_at: string;
  discoverable?: boolean;
  indexable: boolean;
  display_name: string;
  emojis: ApiCustomEmojiJSON[];
  feature_approval: ApiFeaturePolicyJSON;
  fields: ApiAccountFieldJSON[];
  followers_count: number;
  following_count: number;
  group: boolean;
  header: string;
  header_static: string;
  header_description: string;
  id: string;
  last_status_at: string | null;
  locked: boolean;
  show_media: boolean;
  show_media_replies: boolean;
  show_featured: boolean;
  noindex?: boolean;
  note: string;
  roles?: ApiAccountRoleJSON[];
  statuses_count: number;
  uri: string;
  url?: string;
  username: string;
  moved?: ApiAccountJSON;
  suspended?: boolean;
  limited?: boolean;
  memorial?: boolean;
  hide_collections: boolean;
  email_subscriptions?: boolean;
  invalid_handle?: boolean;
  room?: ApiAccountRoomJSON | null;
}

// See app/serializers/rest/muted_account_serializer.rb
export interface ApiMutedAccountJSON extends BaseApiAccountJSON {
  mute_expires_at?: string | null;
}

// For now, we have the same type representing both `Account` and `MutedAccount`
// objects, but we should refactor this in the future.
export type ApiAccountJSON = ApiMutedAccountJSON;

// See app/serializers/rest/familiar_followers_serializer.rb
export type ApiFamiliarFollowersJSON = {
  id: string;
  accounts: ApiAccountJSON[];
}[];
