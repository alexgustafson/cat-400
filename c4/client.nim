from logging import debug
from utils.loop import runLoop
from conf import Config

import systems.network
import systems.input
import systems.video


proc run*(config: Config) =
  logging.debug("Starting client")

  var network = config.systems.network.instance
  network.init()
  network.connect((host: "localhost", port: config.systems.network.port))

  var video = config.systems.video.instance
  video.init(
    title=config.title,
    window=config.systems.video.window,
  )

  var input = config.systems.input.instance
  input.init()

  runLoop(
    updatesPerSecond = 30,
    maxFrequencyCallback = proc(dt: float): bool =
      input.update(dt)
      network.update(dt)
      return true,
    fixedFrequencyCallback = proc(dt: float): bool =
      video.update(dt)
      return true,
  )

  logging.debug("Client shutdown")
