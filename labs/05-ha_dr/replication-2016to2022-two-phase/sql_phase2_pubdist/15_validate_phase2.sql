EXEC sp_validate_redirected_publisher @publisher=N'ServerA',@publisher_db=N'TwojaBaza'; EXEC sp_posttracertoken @publication=N'PubName'; EXEC sp_helptracertokenhistory @publication=N'PubName';
