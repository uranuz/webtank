var webtank = webtank || {};
webtank.ui = webtank.ui || {}

webtank.ui.PlainDatePicker = (function(_super) {
	__extends(PlainDatePicker, _super);

	function PlainDatePicker(opts)
	{
		opts = opts || {};
		opts.controlTypeName = 'webtank.ui.PlainDatePicker';
		_super.call(this, opts);
	}

	return __mixinProto(PlainDatePicker, {
		rawDay: function() {
			return this._elems().filter('.e-day_field').val();
		},
		rawMonth: function() {
			return this._elems().filter('.e-month_field').val();
		},
		rawYear: function() {
			return this._elems().filter('.e-year_field').val();
		}
	});
})(webtank.ITEMControl);

webtank.ui.CheckBoxList = (function(_super) {
	__extends(CheckBoxList, _super);

	function CheckBoxList( opts ) {
		opts = opts || {};
		opts.controlTypeName = 'webtank.ui.CheckBoxList';
		_super.call(this, opts);

		this._block = this._elems().filter(".e-block");
		this._masterSwitchLabel = this._elems().filter(".e-master_switch_label")
			.on( 'click', this.onMasterSwitch_Click.bind(this) );
		this._masterSwitchInput = this._elems().filter(".e-master_switch_input");
		this._itemLabels = this._elems().filter('.e-item_label')
			.on( 'click', this.onItem_Click.bind(this) );
		this._inputs = this._elems().filter('.e-item_input');
	}

	return __mixinProto( CheckBoxList, {
		onMasterSwitch_Click: function() {
			for( var i = 0; i < this._inputs.length; ++i ) {
				var input = $(this._inputs[i]);
				input.prop( 'checked', this._masterSwitchInput.prop( 'checked' ) );
			}
		},
		onResetItem_Click: function() {

		},
		onItem_Click: function(ev) {
			var
				allChecked = true,
				allUnchecked = true,
				input;

			for( var i = 0; i < this._inputs.length; ++i ) {
				input = $(this._inputs[i]);
				if( input.prop('checked') ) {
					allUnchecked = false;
				} else {
					allChecked = false;
				}
				if( !allUnchecked && !allChecked )
					break;
			}

			if( !allChecked && !allUnchecked ) {
				this._masterSwitchInput.prop( 'indeterminate', true );
			} else {
				this._masterSwitchInput.prop( 'indeterminate', false );
				if( allUnchecked ) {
					this._masterSwitchInput.prop( 'checked', false );
				} else if( allChecked ) {
					this._masterSwitchInput.prop( 'checked', true );
				}
			}
		}
	});
})(webtank.ITEMControl);