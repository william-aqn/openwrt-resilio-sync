'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require poll';

var callServiceList = rpc.declare({
	object: 'service', method: 'list', params: ['name'], expect: { '': {} }
});

function isRunning(data) {
	var service = data['resilio-sync'];
	return !!(service && service.instances && service.instances.main && service.instances.main.running);
}

return view.extend({
	load: function() {
		return Promise.all([uci.load('resilio-sync'), callServiceList('resilio-sync')]);
	},
	render: function(data) {
		var m = new form.Map('resilio-sync', _('Resilio Sync'),
			_('Keep files on your external disk and manage shared folders in the Resilio web UI. Runtime installation and initial credentials are configured once over SSH.'));
		var s = m.section(form.NamedSection, 'main', 'resilio-sync');
		s.addremove = false;
		s.tab('general', _('General'));
		s.tab('storage', _('Storage'));
		s.tab('network', _('Network'));

		var o = s.taboption('general', form.Flag, 'enabled', _('Enable service'));
		o.rmempty = false;
		o = s.taboption('general', form.Value, 'device_name', _('Device name'));
		o.rmempty = false;
		o = s.taboption('general', form.Value, 'user', _('Service user'), _('Must be an existing non-root user with access to the selected disk folders.'));
		o.default = 'rslsync';
		o.rmempty = false;

		[['storage_mount', _('Disk mount point')], ['state_dir', _('Private state directory')], ['directory_root', _('Shared folder root')]].forEach(function(item) {
			o = s.taboption('storage', form.Value, item[0], item[1]);
			o.rmempty = false;
			o.validate = function(section, value) {
				return /^\/[A-Za-z0-9_.\/-]+$/.test(value) && !/(\/\.\.?\/|\/\.\.?$|\/\/|\/$)/.test(value)
					? true : _('Use an absolute path without spaces, symlinks or dot segments.');
			};
		});
		o = s.taboption('storage', form.Value, 'storage_uuid', _('ext4 filesystem UUID'), _('Startup is blocked if this disk is absent. State and shared folders must be separate directories below the mount point. Run resilio-sync-setup after changing paths or the service user.'));
		o.rmempty = false;

		o = s.taboption('network', form.Value, 'webui_address', _('Web UI bind address'), _('Use the router LAN address for LAN access. Binding all addresses does not add firewall rules.'));
		o.datatype = 'ip4addr("nomask")';
		o.default = '127.0.0.1';
		o.rmempty = false;
		o = s.taboption('network', form.Value, 'webui_port', _('HTTPS web UI port'));
		o.datatype = 'range(1024,65535)';
		o.default = 8888;
		o.rmempty = false;
		o = s.taboption('network', form.Value, 'webui_login', _('Web UI username'), _('The password is stored outside UCI. Use resilio-sync-setup to create credentials.'));
		o.rmempty = false;
		o = s.taboption('network', form.Value, 'listening_port', _('File transfer port'));
		o.datatype = 'range(1024,65535)';
		o.default = 55555;
		o.rmempty = false;
		o = s.taboption('network', form.Flag, 'use_upnp', _('Request automatic port forwarding'));
		o.rmempty = false;
		['download_limit', 'upload_limit'].forEach(function(name) {
			o = s.taboption('network', form.Value, name, name === 'download_limit' ? _('Download limit (KiB/s)') : _('Upload limit (KiB/s)'), _('0 means unlimited.'));
			o.datatype = 'range(0,2147483647)';
			o.default = 0;
			o.rmempty = false;
		});

		return m.render().then(function(map) {
			var status = E('strong', {}, isRunning(data[1]) ? _('Running') : _('Stopped'));
			var address = uci.get('resilio-sync', 'main', 'webui_address');
			var port = uci.get('resilio-sync', 'main', 'webui_port') || '8888';
			var host = address === '0.0.0.0' ? window.location.hostname : address;
			var children = [E('span', {}, _('Service status: ')), status];
			if (/^(\d{1,3}\.){3}\d{1,3}$/.test(host || '') && /^\d+$/.test(port) && host !== '127.0.0.1') {
				children.push(' ', E('a', { 'class': 'btn cbi-button', 'href': 'https://' + host + ':' + port + '/', 'target': '_blank', 'rel': 'noopener noreferrer' }, _('Open Resilio web UI')));
			}
			map.insertBefore(E('div', { 'class': 'cbi-section' }, children), map.firstChild);
			poll.add(function() {
				return callServiceList('resilio-sync').then(function(result) {
					status.textContent = isRunning(result) ? _('Running') : _('Stopped');
				});
			}, 5);
			return map;
		});
	}
});
