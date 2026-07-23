/* apps/shared/modules/page.js */
import router from "@system.router";
import app from "@system.app";
import MiSync from "./sync.js";

class MiPage {
	constructor(options = {}) {
		this.options = options;
	}

	build() {
		const opts = this.options;
		const isRoot = opts.isRoot || false;

		return {
			...opts,
			private: {
				startX: 0,
				startY: 0,
				...(opts.private || {}),
			},
			onInit() {
				this._unsub = null;
				if (typeof opts.onMessage === "function") {
					this._unsub = MiSync.onMessage((message) => {
						try {
							opts.onMessage.call(this, message);
						} catch (e) {
							MiSync.log(`[PAGE] Error in onMessage: ${e}`);
						}
					});
				}
				if (typeof opts.onInit === "function") {
					try {
						opts.onInit.call(this);
					} catch (e) {
						MiSync.log(`[PAGE] Error in onInit: ${e}`);
					}
				}
			},
			onShow() {
				if (typeof opts.onShow === "function") {
					try {
						opts.onShow.call(this);
					} catch (e) {
						MiSync.log(`[PAGE] Error in onShow: ${e}`);
					}
				}
			},
			onHide() {
				if (typeof opts.onHide === "function") {
					try {
						opts.onHide.call(this);
					} catch (e) {
						MiSync.log(`[PAGE] Error in onHide: ${e}`);
					}
				}
			},
			onDestroy() {
				if (typeof this._unsub === "function") {
					try {
						this._unsub();
					} catch (_) {}
					this._unsub = null;
				}
				if (typeof opts.onDestroy === "function") {
					try {
						opts.onDestroy.call(this);
					} catch (e) {
						MiSync.log(`[PAGE] Error in onDestroy: ${e}`);
					}
				}
			},
			handleSwipe(e) {
				if (e && e.direction === "right" && !isRoot) {
					MiSync.log("[PAGE] Subpage swipe right -> calling router.back()");
					router.back();
				}
				if (typeof opts.handleSwipe === "function") {
					try {
						opts.handleSwipe.call(this, e);
					} catch (err) {
						MiSync.log(`[PAGE] Error in custom handleSwipe: ${err}`);
					}
				}
			},
			handleTouchStart(e) {
				if (e && e.touches && e.touches.length > 0) {
					this.startX = e.touches[0].clientX;
					this.startY = e.touches[0].clientY;
				}
				if (typeof opts.handleTouchStart === "function") {
					try {
						opts.handleTouchStart.call(this, e);
					} catch (_) {}
				}
			},
			handleTouchMove(e) {
				if (e && e.touches && e.touches.length > 0) {
					const touch = e.touches[0];
					const deltaX = touch.clientX - this.startX;
					const deltaY = touch.clientY - this.startY;
					if (isRoot && (typeof this.currentIndex === "undefined" || this.currentIndex === 0)) {
						if (this.startX < 50 && deltaX > 35 && Math.abs(deltaX) > Math.abs(deltaY) * 1.2) {
							MiSync.log("[PAGE] Left-edge swipe detected on swiper slide 0 -> terminating app");
							app.terminate();
							return;
						}
					}
				}
				if (typeof opts.handleTouchMove === "function") {
					try {
						opts.handleTouchMove.call(this, e);
					} catch (_) {}
				}
			},
			send(command, data = {}) {
				MiSync.send(command, data);
			},
		};
	}
}

export default function(options) {
	return new MiPage(options).build();
}
