CREATE TABLE `greenhouses`
(
    `id` INT NOT NULL AUTO_INCREMENT,
    `owner_id` INT NOT NULL,

    `pos_x` FLOAT NOT NULL,
    `pos_y` FLOAT NOT NULL,
    `pos_z` FLOAT NOT NULL,

    `stage` INT NOT NULL DEFAULT 0,

    `created_at` INT NOT NULL,

    `upgrade_type` INT NOT NULL DEFAULT 0,

    PRIMARY KEY(`id`)
);