'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require poll';
'require ui';

var callServiceList = rpc.declare({
	object: 'service', method: 'list', params: ['name'], expect: { '': {} }
});
var callSetPassword = rpc.declare({
	object: 'resilio-sync', method: 'set_password', params: ['password'], expect: { '': {} }
});

function changePassword() {
	var password = E('input', { 'id': 'resilio-new-password', 'type': 'password', 'autocomplete': 'new-password', 'maxlength': 128, 'class': 'cbi-input-password' });
	var confirmation = E('input', { 'id': 'resilio-confirm-password', 'type': 'password', 'autocomplete': 'new-password', 'maxlength': 128, 'class': 'cbi-input-password' });
	var error = E('p', { 'class': 'error', 'role': 'alert' });
	var cancel = E('button', { 'class': 'btn', 'click': function() { password.value = confirmation.value = ''; ui.hideModal(); } }, _('Cancel'));
	var save = E('button', { 'class': 'btn cbi-button-positive', 'click': function() {
		error.textContent = '';
		if (password.value.length < 12 || password.value.length > 128 || /[^\x20-\x7e]/.test(password.value)) {
			error.textContent = _('Use 12 to 128 characters: English letters, numbers, symbols or spaces.');
			return;
		}
		if (password.value !== confirmation.value) {
			error.textContent = _('Passwords do not match.');
			return;
		}
		save.disabled = cancel.disabled = true;
		password.disabled = confirmation.disabled = true;
		return callSetPassword(password.value).then(function(result) {
			password.value = confirmation.value = '';
			if (!result.ok) {
				var messages = {
					invalid_password: _('Use 12 to 128 characters: English letters, numbers, symbols or spaces.'),
					setup_required: _('Complete initial setup over SSH before changing the password.'),
					busy: _('Another password change is in progress. Try again.'),
					reload_failed: _('The service could not reload. The previous password was restored. Check the service settings.'),
					rollback_failed: _('The service could not reload or restore the previous password. Check storage and credentials over SSH.'),
					save_failed: _('The password could not be saved. Check free space and file permissions.')
				};
				error.textContent = messages[result.code] || _('The password could not be changed.');
				return;
			}
			ui.hideModal();
			ui.addNotification(null, E('p', {}, result.reloading
				? _('Password changed. Resilio is reloading; sign in to its web UI with the new password.')
				: _('Password changed. It will be used when Resilio starts. The service remains stopped.')), 'info');
		}).catch(function() {
			password.value = confirmation.value = '';
			error.textContent = _('No confirmation was received. Check whether the new password works before trying again.');
		}).finally(function() {
			save.disabled = cancel.disabled = false;
			password.disabled = confirmation.disabled = false;
		});
	} }, _('Change password'));
	ui.showModal(_('Change Resilio web UI password'), [
		E('p', {}, _('You do not need the old Resilio password. This takes effect immediately and briefly restarts a running Resilio service. Save and apply other settings first.')),
		E('p', {}, [E('label', { 'for': 'resilio-new-password' }, _('New password')), E('br'), password]),
		E('p', {}, [E('label', { 'for': 'resilio-confirm-password' }, _('Repeat password')), E('br'), confirmation]),
		error,
		E('div', { 'class': 'right' }, [cancel, ' ', save])
	]);
	password.focus();
}

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
		o = s.taboption('network', form.Value, 'webui_login', _('Web UI username'));
		o.rmempty = false;
		o = s.taboption('network', form.Button, '_change_password', _('Web UI password'), _('Set a new password even if you forgot the old one. Only its hash is stored; the current password cannot be displayed.'));
		o.inputtitle = _('Change password');
		o.inputstyle = 'apply';
		o.onclick = changePassword;
		o.write = function() {};
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
