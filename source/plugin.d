import std.stdio;
import deimos.alsa.pcm;
import deimos.alsa.conf;
import deimos.alsa.global;
import core.stdc.errno;
import core.sys.posix.poll;
import core.memory;
import std.string;
import core.runtime;
import std.socket;
import std.conv;
import core.stdc.stdio;

static enum SND_PCM_IOPLUG_VERSION_MAJOR = 1;	/**< Protocol major version */
static enum SND_PCM_IOPLUG_VERSION_MINOR = 0;	/**< Protocol minor version */
static enum SND_PCM_IOPLUG_VERSION_TINY	= 2;	/**< Protocol tiny version */
static enum SND_PCM_IOPLUG_FLAG_LISTED = 1;
static enum SND_PCM_STREAM_PLAYBACK = 0;
/**
 * IO-plugin protocol version
 */
static enum SND_PCM_IOPLUG_VERSION	= ((SND_PCM_IOPLUG_VERSION_MAJOR<<16) | (SND_PCM_IOPLUG_VERSION_MINOR<<8) | (SND_PCM_IOPLUG_VERSION_TINY));


class PluginState {
  snd_pcm_ioplug *handle;
  Socket[2] sockets;
  snd_pcm_ioplug_callback *callbacks;
  immutable char* name;
  this() {
    callbacks = new snd_pcm_ioplug_callback();
    callbacks.pointer = &pointer;
    callbacks.start = &start;
    callbacks.stop = &stop;

    sockets = socketPair();
    this.name = "roomio".toStringz();

    handle = new snd_pcm_ioplug(SND_PCM_IOPLUG_VERSION, name, SND_PCM_IOPLUG_FLAG_LISTED, sockets[0].handle, POLLIN, 0, callbacks, cast(void*)this);
  }
}

  auto toRange(snd_config_t *conf) {
    struct Result {
      private {
        snd_config_t *conf;
        snd_config_iterator_t pos, next;
      }
      this(snd_config_t *conf) {
        this.conf = conf;
        pos = snd_config_iterator_first(conf);
        next = snd_config_iterator_next(pos);
      }
      @property bool empty() {
        return pos != snd_config_iterator_end(conf);
      }
      auto front() {
        return snd_config_iterator_entry(pos);
      }
      auto popFront() {
        pos = next;
        next = snd_config_iterator_next(pos);
      }
    }
    return Result(conf);
  }
  void log(string msg, in string file = __FILE__, in size_t line = __LINE__, in string fun = __FUNCTION__) {
    // snd_lib_error(file.toStringz, cast(int)line, fun.toStringz, 0, msg.toStringz);
    printf(msg.toStringz);
    // writeln(msg);
  }

extern (C) {
  alias snd_output_t = void;
  struct snd_pcm_ioplug {
	/**
	 * protocol version; #SND_PCM_IOPLUG_VERSION must be filled here
	 * before calling #snd_pcm_ioplug_create()
	 */
	uint version_;
	/**
	 * name of this plugin; must be filled before calling #snd_pcm_ioplug_create()
	 */
	const char *name;
	uint flags;	/**< SND_PCM_IOPLUG_FLAG_XXX */
	int poll_fd;		/**< poll file descriptor */
	uint poll_events;	/**< poll events */
	uint mmap_rw;		/**< pseudo mmap mode */
	/**
	 * callbacks of this plugin; must be filled before calling #snd_pcm_ioplug_create()
	 */
	const snd_pcm_ioplug_callback *callback;
	/**
	 * private data, which can be used freely in the driver callbacks
	 */
	void *private_data;
	/**
	 * PCM handle filled by #snd_pcm_extplug_create()
	 */
	snd_pcm_t *pcm;

	snd_pcm_stream_t stream;	/**< stream direcion; read-only */
	snd_pcm_state_t state;		/**< current PCM state; read-only */
	snd_pcm_uframes_t appl_ptr;	/**< application pointer; read-only */
	snd_pcm_uframes_t hw_ptr;	/**< hw pointer; read-only */
	int nonblock;			/**< non-block mode; read-only */

	snd_pcm_access_t access;	/**< access type; filled after hw_params is called */
	snd_pcm_format_t format;	/**< PCM format; filled after hw_params is called */
	uint channels;		/**< number of channels; filled after hw_params is called */
	uint rate;		/**< rate; filled after hw_params is called */
	snd_pcm_uframes_t period_size;	/**< period size; filled after hw_params is called */
	snd_pcm_uframes_t buffer_size;	/**< buffer size; filled after hw_params is called */
};

/** Callback table of ioplug */
struct snd_pcm_ioplug_callback {
	int function(snd_pcm_ioplug *io) start;  // start the PCM; required
	int function(snd_pcm_ioplug *io) stop;  // stop the PCM; required
	snd_pcm_sframes_t function(snd_pcm_ioplug *io) pointer;  // get the current DMA position; required
	snd_pcm_sframes_t function(snd_pcm_ioplug *io,  // transfer the data; optional
			      const snd_pcm_channel_area_t *areas,
			      snd_pcm_uframes_t offset,
			      snd_pcm_uframes_t size) transfer;
		int function(snd_pcm_ioplug *io) close;  // close the PCM; optional
	int function(snd_pcm_ioplug *io, snd_pcm_hw_params_t *params) hw_params;  // hw_params; optional
	int function(snd_pcm_ioplug *io) hw_free;  // hw_free; optional
	int function(snd_pcm_ioplug *io, snd_pcm_sw_params_t *params) sw_params;  // sw_params; optional
	int function(snd_pcm_ioplug *io) prepare;  // prepare; optional
	int function(snd_pcm_ioplug *io) drain;  // drain; optional
	int function(snd_pcm_ioplug *io, int enable) pause;  // toggle pause; optional
	int function(snd_pcm_ioplug *io) resume;  // resume; optional
	int function(snd_pcm_ioplug *io) poll_descriptors_count;  // poll descriptors count; optional
	int function(snd_pcm_ioplug *io, pollfd *pfd, uint space) poll_descriptors;  // poll descriptors; optional
	int function(snd_pcm_ioplug *io, pollfd *pfd, uint nfds, ushort *revents) poll_revents;  // mangle poll events; optional
	void function(snd_pcm_ioplug *io, snd_output_t * out_) dump;  // dump; optional
	int function(snd_pcm_ioplug *io, snd_pcm_sframes_t *delayp) delay;  // get the delay for the running PCM; optional; since v1.0.1
	snd_pcm_chmap_query_t **function(snd_pcm_ioplug *io) query_chmaps;  // query the channel maps; optional; since v1.0.2
	snd_pcm_chmap_t *function(snd_pcm_ioplug *io) get_chmap;  // get the channel map; optional; since v1.0.2
	int function(snd_pcm_ioplug *io, const snd_pcm_chmap_t *map) set_chmap;  // set the channel map; optional; since v1.0.2
};

  static snd_pcm_sframes_t pointer(snd_pcm_ioplug *io) {
    log("pointer");
    return 0;
  }
  static int start(snd_pcm_ioplug *io) {
    log("start");
    return 0;
  }

  static int stop(snd_pcm_ioplug *io) {
    log("stop");
    return 0;
  }

  extern int snd_pcm_ioplug_create(snd_pcm_ioplug *io, const char *name, snd_pcm_stream_t stream, int mode);
  alias snd_lib_error_handler_t = void function(const char *file, int line, const char *f, int err, const char *fmt,...);
  extern __gshared snd_lib_error_handler_t snd_lib_error;

  export int _snd_pcm_test_open (snd_pcm_t **pcmp, const char *name,
                                 snd_config_t *root, snd_config_t *conf,
                                 snd_pcm_stream_t stream, int mode)  {
    if (stream != SND_PCM_STREAM_PLAYBACK)
      return -EINVAL;
    log("Were are in!");

    // foreach(cnf; conf.toRange) {
    //   const (char)* configName;
    //   if (snd_config_get_id(cnf, &configName) < 0)
    //     continue;
    //   writefln("ioplug: Got config %s", configName.to!string);
    // }

    auto plugin = new PluginState();
    GC.addRoot(cast(void*)plugin);

    return snd_pcm_ioplug_create(plugin.handle, plugin.name, stream, mode);
  }
  export char __snd_pcm_test_open_dlsym_pcm_001;
}

shared static this() {
  log("ioplug: initialize runtime");
  Runtime.initialize();
}
