'use strict';
'require view';
'require form';
'require fs';
'require ui';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('turboacc', _('Turbo ACC 网络加速'),
			_('一键开启 BBR 拥塞控制、软件/硬件流量分载（HW NAT）与 FullCone NAT。' +
			  '设置会写入标准的 fw4 选项与 sysctl 配置，重启或系统升级后依然生效。'));

		s = m.section(form.NamedSection, 'config', 'turboacc', _('加速选项'));
		s.anonymous = true;

		o = s.option(form.Flag, 'bbr', _('BBR 拥塞控制'),
			_('启用 fq + BBR，改善高延迟、高丢包链路的吞吐与稳定性。'));
		o.rmempty = false;
		o.default = '1';

		o = s.option(form.Flag, 'flow_offloading', _('软件流量分载'),
			_('由 netfilter flowtable 直接转发已建立的连接，显著降低转发时的 CPU 占用。'));
		o.rmempty = false;
		o.default = '1';

		o = s.option(form.Flag, 'flow_offloading_hw', _('硬件流量分载 (HW NAT)'),
			_('需要网卡支持硬件 Offload。使用透明代理（nikki / TPROXY / TUN）时建议关闭，' +
			  '否则可能出现代理规则不生效。'));
		o.rmempty = false;
		o.default = '1';

		o = s.option(form.Flag, 'fullcone', _('FullCone NAT'),
			_('全锥形 NAT，改善游戏与 P2P 的 NAT 类型（UDP 生效）。依赖 kmod-nft-fullcone。'));
		o.rmempty = false;
		o.default = '1';

		return m.render();
	},

	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			return fs.exec('/etc/init.d/turboacc', [ 'reload' ]);
		}).then(function() {
			ui.changes.apply(mode);
		});
	}
});
