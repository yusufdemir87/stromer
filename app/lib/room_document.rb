# frozen_string_literal: true

# The standalone page a room is drawn on, served to a sandboxed frame (RoomsController). The only script on it
# is the bridge below, whose hash the page's Content-Security-Policy allows: it tells the page around the frame
# which drawer a visitor asked for, and nothing else. Whatever script a creator might write is blocked.
class RoomDocument
  BRIDGE = <<~JS.squish.freeze
    (function () {
      var hooks = #{RoomSanitizer::HOOKS.to_json};
      function find(node) { return node && node.closest ? node.closest('[data-open]') : null; }
      function open(el) {
        var target = el.getAttribute('data-open');
        if (hooks.indexOf(target) !== -1) { parent.postMessage({ type: 'stromer-room-open', target: target }, '*'); }
      }
      document.addEventListener('click', function (e) { var el = find(e.target); if (el) { open(el); } });
      document.addEventListener('keydown', function (e) {
        if (e.key !== 'Enter' && e.key !== ' ') { return; }
        var el = find(e.target);
        if (el) { e.preventDefault(); open(el); }
      });
    })();
  JS

  BRIDGE_SOURCE = "'sha256-#{Digest::SHA256.base64digest(BRIDGE)}'".freeze

  BASE_CSS = <<~CSS.squish.freeze
    html,body{margin:0;height:100%;overflow:hidden;background:transparent}
    body>svg{display:block;width:100%;height:100%}
    [data-open]{cursor:pointer;outline:none}
    [data-open]:hover,[data-open]:focus-visible{filter:brightness(1.14)}
    [data-open]:focus-visible{outline:3px solid #fff;outline-offset:3px}
    @media (prefers-reduced-motion:reduce){*,*::before,*::after{animation:none!important;transition:none!important}}
  CSS

  # The Content-Security-Policy every page that shows a creator's drawing must carry: no network, no form, no
  # nested frame, only the fixed bridge script, and a sandbox. Used by the public room and the admin preview.
  def self.apply_policy(policy)
    policy.default_src     :none
    policy.base_uri        :none
    policy.form_action     :none
    policy.frame_ancestors :self
    policy.frame_src       :none
    policy.child_src       :none
    policy.worker_src      :none
    policy.manifest_src    :none
    policy.media_src       :none
    policy.object_src      :none
    policy.connect_src     :none
    policy.font_src        :none
    policy.img_src         :data
    policy.style_src       :unsafe_inline
    policy.script_src      BRIDGE_SOURCE
    policy.sandbox         'allow-scripts'
  end

  def self.render(html, title:, lang: 'en')
    <<~HTML
      <!DOCTYPE html>
      <html lang="#{ERB::Util.html_escape(lang)}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex"><title>#{ERB::Util.html_escape(title)}</title><style>#{BASE_CSS}</style></head><body>#{html}<script>#{BRIDGE}</script></body></html>
    HTML
  end
end
