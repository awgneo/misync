/* apps/shared/modules/mipage.js */
export default function MiPage(options = {}) {
	return {
		...options,
		private: {
			startX: 0,
			startY: 0,
			...(options.private || {}),
		},
		handleTouchStart(e) {
			if (e.touches && e.touches.length > 0) {
				this.startX = e.touches[0].clientX;
				this.startY = e.touches[0].clientY;
			}
			if (typeof options.handleTouchStart === "function") {
				options.handleTouchStart.call(this, e);
			}
		},
		handleTouchMove(e) {
			if (e.touches && e.touches.length > 0) {
				const touch = e.touches[0];
				const deltaX = touch.clientX - this.startX;
				const deltaY = touch.clientY - this.startY;
				if (this.startX < 50 && deltaX > 30 && Math.abs(deltaX) > Math.abs(deltaY)) {
					this.$app.exit();
					return;
				}
			}
			if (typeof options.handleTouchMove === "function") {
				options.handleTouchMove.call(this, e);
			}
		},
	};
}
