from logging import nil
from utils.loop import runLoop
from utils.states import State, None, switch
from core import config


type
  Loading* = object of State
  Running* = object of State
  Paused* = object of State

var
  state: ref State = new(ref None)  # TODO: add "not nil"

let
  network* = config.networkBackend

proc update(dt:float): bool =
  return not (state of ref None)

proc start*() =
  logging.debug("Process created")
  state = state.switch(new(ref Loading))
  runLoop(updatesPerSecond = 30, fixedFrequencyHandlers = @[update])
  logging.debug("Process stopped")
