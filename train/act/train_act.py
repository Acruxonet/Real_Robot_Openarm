"""Run the official LeRobot trainer with OpenArm letterbox preprocessing."""

try:
    from .letterbox import letterbox
except ImportError:  # Supports running this file directly.
    from letterbox import letterbox


def main() -> None:
    """Attach the transform through whichever official dataset API is available."""
    from lerobot.scripts import lerobot_train

    def attach(dataset):
        """Set the per-frame transform on one LeRobot dataset."""
        if dataset is None:
            return None
        if hasattr(dataset, "set_image_transforms"):
            dataset.set_image_transforms(letterbox)
        else:
            dataset.image_transforms = letterbox
        return dataset

    if hasattr(lerobot_train, "make_train_eval_datasets"):
        official_factory = lerobot_train.make_train_eval_datasets

        def make_train_eval_datasets(cfg):
            """Wrap both datasets returned by newer LeRobot trainers."""
            train, evaluation = official_factory(cfg)
            return attach(train), attach(evaluation)

        lerobot_train.make_train_eval_datasets = make_train_eval_datasets
    elif hasattr(lerobot_train, "make_dataset"):
        official_factory = lerobot_train.make_dataset

        def make_dataset(cfg):
            """Wrap the single dataset used by older LeRobot trainers."""
            return attach(official_factory(cfg))

        lerobot_train.make_dataset = make_dataset
    else:
        raise AttributeError("LeRobot trainer exposes neither dataset factory API")

    lerobot_train.main()


if __name__ == "__main__":
    main()
