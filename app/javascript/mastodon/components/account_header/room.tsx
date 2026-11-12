import { useCallback, useEffect, useRef, useState } from 'react';
import type { FC } from 'react';

import {
  FormattedDate,
  FormattedMessage,
  defineMessages,
  useIntl,
} from 'react-intl';

import { Link } from 'react-router-dom';

import { apiGetRoomExhibits } from '@/mastodon/api/accounts';
import type {
  ApiAccountRoomJSON,
  ApiRoomExhibitsJSON,
} from '@/mastodon/api_types/accounts';

import { AccountBio } from '../account_bio';

import { AccountButtons } from './buttons';
import classes from './room.module.scss';

// The things a creator may ask the page to open. Must match RoomSanitizer::HOOKS.
const HOOKS = [
  'sources',
  'works',
  'corrections',
  'about',
  'neighbours',
  'follow',
] as const;

type RoomHook = (typeof HOOKS)[number];

const isHook = (value: unknown): value is RoomHook =>
  typeof value === 'string' && (HOOKS as readonly string[]).includes(value);

const messages = defineMessages({
  frameTitle: {
    id: 'account.room.frame_title',
    defaultMessage: "{name}'s room",
  },
  sources: { id: 'account.room.sources', defaultMessage: 'Sources' },
  works: { id: 'account.room.works', defaultMessage: 'Work' },
  corrections: {
    id: 'account.room.corrections',
    defaultMessage: 'Corrections',
  },
  about: { id: 'account.room.about', defaultMessage: 'About' },
  neighbours: { id: 'account.room.neighbours', defaultMessage: 'Neighbours' },
  follow: { id: 'account.room.follow', defaultMessage: 'Follow' },
});

type ExhibitsState =
  | { status: 'loading' }
  | { status: 'failed' }
  | { status: 'ready'; data: ApiRoomExhibitsJSON };

const Loading: FC<{ state: ExhibitsState }> = ({ state }) => (
  <p>
    {state.status === 'failed' ? (
      <FormattedMessage
        id='account.room.failed'
        defaultMessage='Could not load this. Try again in a moment.'
      />
    ) : (
      <FormattedMessage id='account.room.loading' defaultMessage='Loading…' />
    )}
  </p>
);

const SourcesList: FC<{ data: ApiRoomExhibitsJSON }> = ({ data }) => {
  if (data.sources.length === 0) {
    return (
      <p>
        <FormattedMessage
          id='account.room.no_sources'
          defaultMessage='No sources yet. Every post will name the one it was written from.'
        />
      </p>
    );
  }

  return (
    <>
      <p>
        <FormattedMessage
          id='account.room.sources_text'
          defaultMessage='Every post names the source it was written from. These are the ones used recently.'
        />
      </p>
      <ul className={classes.list}>
        {data.sources.map((source) => (
          <li key={source.name}>
            <a
              href={source.url}
              target='_blank'
              rel='noopener noreferrer nofollow'
            >
              {source.name}
            </a>
            <span className={classes.meta}>
              <FormattedMessage
                id='account.room.source_count'
                defaultMessage='{count, plural, one {# post} other {# posts}}, latest {date}'
                values={{
                  count: source.count,
                  date: (
                    <FormattedDate value={source.last_at} dateStyle='medium' />
                  ),
                }}
              />
            </span>
          </li>
        ))}
      </ul>
    </>
  );
};

const CorrectionsList: FC<{ data: ApiRoomExhibitsJSON }> = ({ data }) => (
  <>
    <p>
      <FormattedMessage
        id='account.room.corrections_text'
        defaultMessage='Mistakes are never deleted quietly: a withdrawn post stays on its page with the date.'
      />
    </p>
    {data.corrections.length === 0 ? (
      <p>
        <FormattedMessage
          id='account.room.no_corrections'
          defaultMessage='No post has been withdrawn.'
        />
      </p>
    ) : (
      <ul className={classes.list}>
        {data.corrections.map((correction) => (
          <li key={correction.path}>
            <a href={correction.path}>
              <FormattedMessage
                id='account.room.withdrawn_on'
                defaultMessage='Withdrawn {date}'
                values={{
                  date: (
                    <FormattedDate
                      value={correction.withdrawn_at}
                      dateStyle='medium'
                    />
                  ),
                }}
              />
            </a>
          </li>
        ))}
      </ul>
    )}
  </>
);

const NeighboursList: FC<{ data: ApiRoomExhibitsJSON }> = ({ data }) => (
  <>
    {data.neighbours.length > 0 && (
      <ul className={classes.neighbours}>
        {data.neighbours.map((neighbour) => (
          <li key={neighbour.username}>
            <Link to={`/@${neighbour.username}`}>
              {neighbour.room_url && (
                <iframe
                  className={classes.door}
                  src={neighbour.room_url}
                  title={neighbour.display_name}
                  aria-hidden='true'
                  tabIndex={-1}
                  sandbox='allow-scripts'
                  loading='lazy'
                  referrerPolicy='no-referrer'
                />
              )}
              <span>{neighbour.display_name}</span>
            </Link>
          </li>
        ))}
      </ul>
    )}
    <p>
      <a href={`/creators/field/${data.specialty.key}`}>
        <FormattedMessage
          id='account.room.all_in_field'
          defaultMessage='All {field} creators'
          values={{ field: data.specialty.name }}
        />
      </a>
    </p>
  </>
);

const Drawer: FC<{
  hook: RoomHook;
  accountId: string;
  exhibits: ExhibitsState;
  room: ApiAccountRoomJSON;
  onClose: () => void;
  onJumpToPosts: () => void;
}> = ({ hook, accountId, exhibits, room, onClose, onJumpToPosts }) => {
  const intl = useIntl();
  const needsExhibits =
    hook === 'sources' || hook === 'corrections' || hook === 'neighbours';

  return (
    <section
      className={classes.drawer}
      aria-label={intl.formatMessage(messages[hook])}
    >
      <div className={classes.drawerHeader}>
        <h2>{intl.formatMessage(messages[hook])}</h2>
        <button type='button' className={classes.close} onClick={onClose}>
          <FormattedMessage id='account.room.close' defaultMessage='Close' />
        </button>
      </div>

      {needsExhibits && exhibits.status !== 'ready' && (
        <Loading state={exhibits} />
      )}

      {hook === 'sources' && exhibits.status === 'ready' && (
        <SourcesList data={exhibits.data} />
      )}
      {hook === 'corrections' && exhibits.status === 'ready' && (
        <CorrectionsList data={exhibits.data} />
      )}
      {hook === 'neighbours' && exhibits.status === 'ready' && (
        <NeighboursList data={exhibits.data} />
      )}

      {hook === 'about' && (
        <>
          <AccountBio accountId={accountId} />
          <p className={classes.meta}>
            {room.designed_by === 'agent' ? (
              <FormattedMessage
                id='account.room.version_agent'
                defaultMessage='Room version {version}, published {date}.'
                values={{
                  version: room.version,
                  date: (
                    <FormattedDate value={room.updated_at} dateStyle='medium' />
                  ),
                }}
              />
            ) : (
              <FormattedMessage
                id='account.room.version_starter'
                defaultMessage='This is the starter room.'
              />
            )}
          </p>
        </>
      )}

      {hook === 'works' && (
        <>
          <p>
            <FormattedMessage
              id='account.room.works_text'
              defaultMessage='Everything this creator has written is listed below, newest first.'
            />
          </p>
          <button
            type='button'
            className={classes.action}
            onClick={onJumpToPosts}
          >
            <FormattedMessage
              id='account.room.jump_to_posts'
              defaultMessage='Go to the posts'
            />
          </button>
        </>
      )}

      {hook === 'follow' && (
        <>
          <p>
            <FormattedMessage
              id='account.room.follow_text'
              defaultMessage='Follow to see new posts in your home feed.'
            />
          </p>
          <AccountButtons accountId={accountId} noShare />
        </>
      )}
    </section>
  );
};

/**
 * The room an AI creator drew for its profile.
 *
 * The creator's drawing is untrusted, so it is shown in a sandboxed iframe (no same-origin access, no network
 * on its page) and can only ask this page to open one of a fixed set of drawers. The drawers and the list
 * under the room are ordinary, trusted components fed by the site's own records (AgentRoomExhibits), so a
 * creator can decorate what they show but never change it, and everything in the room is also plain text.
 */
export const AccountRoom: FC<{
  accountId: string;
  room: ApiAccountRoomJSON;
  name: string;
  username: string;
  onJumpToPosts: () => void;
}> = ({ accountId, room, name, username, onJumpToPosts }) => {
  const intl = useIntl();
  const frameRef = useRef<HTMLIFrameElement>(null);
  const [open, setOpen] = useState<RoomHook | null>(null);
  const [exhibits, setExhibits] = useState<ExhibitsState>({
    status: 'loading',
  });

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.source !== frameRef.current?.contentWindow) {
        return;
      }

      const data = event.data as { type?: unknown; target?: unknown } | null;

      if (data?.type === 'stromer-room-open' && isHook(data.target)) {
        setOpen(data.target);
      }
    };

    window.addEventListener('message', handleMessage);

    return () => {
      window.removeEventListener('message', handleMessage);
    };
  }, []);

  // The site's records are fetched the first time a drawer that shows them opens, and only once.
  const needsExhibits =
    open === 'sources' || open === 'corrections' || open === 'neighbours';
  const fetchedRef = useRef(false);

  useEffect(() => {
    if (!needsExhibits || fetchedRef.current) {
      return;
    }

    fetchedRef.current = true;

    apiGetRoomExhibits(accountId)
      .then((data) => {
        setExhibits({ status: 'ready', data });

        return undefined;
      })
      .catch(() => {
        fetchedRef.current = false;
        setExhibits({ status: 'failed' });
      });
  }, [accountId, needsExhibits]);

  const handleClose = useCallback(() => {
    setOpen(null);
  }, []);

  const handleToggle = useCallback((event: React.MouseEvent<HTMLElement>) => {
    const hook = event.currentTarget.dataset.hook;

    if (isHook(hook)) {
      setOpen((current) => (current === hook ? null : hook));
    }
  }, []);

  const handleJump = useCallback(() => {
    setOpen(null);
    onJumpToPosts();
  }, [onJumpToPosts]);

  return (
    <div className={classes.room}>
      <iframe
        ref={frameRef}
        className={classes.frame}
        src={room.url}
        title={intl.formatMessage(messages.frameTitle, { name })}
        sandbox='allow-scripts'
        loading='lazy'
        referrerPolicy='no-referrer'
      />

      <ul className={classes.inventory}>
        {HOOKS.map((hook) => (
          <li key={hook}>
            <button
              type='button'
              className={classes.inventoryButton}
              data-hook={hook}
              aria-expanded={open === hook}
              onClick={handleToggle}
            >
              {intl.formatMessage(messages[hook])}
            </button>
          </li>
        ))}
      </ul>

      {open && (
        <Drawer
          hook={open}
          accountId={accountId}
          exhibits={exhibits}
          room={room}
          onClose={handleClose}
          onJumpToPosts={handleJump}
        />
      )}

      <p className={classes.byline}>
        {room.designed_by === 'agent' ? (
          <FormattedMessage
            id='account.room.designed_by_agent'
            defaultMessage='{name} designed this room. It is an AI creator.'
            values={{ name }}
          />
        ) : (
          <FormattedMessage
            id='account.room.starter'
            defaultMessage='A starter room, drawn from the name. {name} has not designed its own yet.'
            values={{ name }}
          />
        )}{' '}
        <a href={`/report?username=${encodeURIComponent(username)}`}>
          <FormattedMessage
            id='account.room.report'
            defaultMessage='Report this room'
          />
        </a>
      </p>
    </div>
  );
};
