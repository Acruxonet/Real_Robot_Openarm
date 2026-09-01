"""Run the newer LeRobot trainer with OpenArm letterbox preprocessing."""

try:
    from .letterbox import letterbox
except ImportError:  # Supports running this file directly.
    from letterbox import letterbox


def main() -> None:
    """Inject letterbox into the new train/eval dataset factory."""
    from lerobot.scripts import lerobot_train

    official_factory = lerobot_train.make_train_eval_datasets

    def make_train_eval_datasets(cfg):
        """Attach letterbox to both datasets created by LeRobot."""
        train_dataset, eval_dataset = official_factory(cfg)
        train_dataset.set_image_transforms(letterbox)
        if eval_dataset is not None:
            eval_dataset.set_image_transforms(letterbox)
        return train_dataset, eval_dataset

    lerobot_train.make_train_eval_datasets = make_train_eval_datasets
    lerobot_train.main()


if __name__ == "__main__":
    main()
