# Confidence calibration

The API distinguishes provider confidence from system confidence. The current
foundation has no resolved-outcome dataset, so it does not claim calibrated
accuracy; `calibration` is a model-state routing feature only. A future learner
must use delayed outcomes and time-safe validation to fit temperature, Platt,
isotonic, or Beta calibration, then version the fitted artifact and report
Brier score and expected calibration error.
